import Defaults
import KeyboardShortcuts
import SwiftUI
import Vision

private struct KeyboardShortcutHelpModifier: ViewModifier {
  // A nil name produces help text without a keyboard shortcut substitution.
  let name: KeyboardShortcuts.Name?
  let key: String
  let tableName: String
  let comment: String = ""
  let replacementKey: String

  // Use the same localized description for visual help and the accessibility label.
  private var resolvedText: Text? {
    let localized = NSLocalizedString(key, tableName: tableName, comment: comment)
    guard let name else {
      return Text(localized)
    }
    guard let shortcut = KeyboardShortcuts.Shortcut(name: name) else {
      return nil
    }
    return Text(localized.replacingOccurrences(of: "{\(replacementKey)}", with: shortcut.description))
  }

  func body(content: Content) -> some View {
    if let resolvedText {
      content
        .help(resolvedText)
        .accessibilityLabel(resolvedText)
    } else {
      content
    }
  }
}

struct ToolbarButton<Label: View>: View {
  @Environment(AppState.self) private var appState

  let action: @MainActor () -> Void
  let label: () -> Label

  var body: some View {
    Button(action: action) {
      label()
    }
    .buttonStyle(.plain)
    .frame(height: 23)
    .onHover(perform: { inside in
      if let window = appState.appDelegate?.panel {
        window.isMovableByWindowBackground = !inside
      }
    })
  }

  func shortcutKeyHelp(
    name: KeyboardShortcuts.Name? = nil,
    key: String,
    tableName: String,
    replacementKey: String = ""
  ) -> some View {
    self.modifier(
      KeyboardShortcutHelpModifier(
        name: name,
        key: key,
        tableName: tableName,
        replacementKey: replacementKey
      )
    )
  }

}

struct ToolbarView: View {
  @State private var appState = AppState.shared

  @Namespace var unionNamespace

  enum Section: Hashable {
    case itemOptions
  }

  private var shouldUnpin: Bool {
    return appState.navigator.selection.items.allSatisfy { $0.isPinned }
  }

  private var pinActionDisabled: Bool {
    return appState.navigator.selection.items.contains { $0.isPinned }
      && appState.navigator.selection.items.contains { !$0.isPinned }
  }

  private var selectedImageItem: HistoryItemDecorator? {
    guard appState.navigator.selection.count == 1,
          let item = appState.navigator.selection.first,
          item.hasImage else {
      return nil
    }

    return item
  }

  // Scan the selected image for a QR code and copy its content.
  // If multiple codes are present, the first detected one wins.
  private func scanQRCode() {
    guard let image = selectedImageItem?.item.image,
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return
    }

    Task.detached(priority: .userInitiated) {
      let request = VNDetectBarcodesRequest()
      request.symbologies = [.qr]
      let handler = VNImageRequestHandler(cgImage: cgImage)
      try? handler.perform([request])

      guard let payload = request.results?.first?.payloadStringValue else {
        return
      }

      await MainActor.run {
        Clipboard.shared.copyInMaccy(payload)
      }
    }
  }

  // Single selected text item that can be masked.
  private var selectedMaskableItem: HistoryItemDecorator? {
    guard appState.navigator.selection.count == 1,
          let item = appState.navigator.selection.first,
          !item.hasImage else {
      return nil
    }

    return item
  }

  var body: some View {
    // Keep the buttons in the corner next to the popup content:
    // right corner when the preview slides out right, left corner otherwise.
    let alignLeft = appState.preview.placement == .left

    HStack {
      if !alignLeft && !appState.navigator.selection.isEmpty {
        Spacer()
      }

      if !appState.navigator.selection.isEmpty {
        if selectedImageItem != nil {
          ToolbarButton {
            scanQRCode()
          } label: {
            Image(systemName: "qrcode.viewfinder")
          }
          .shortcutKeyHelp(key: "ScanQRCode", tableName: "PreviewItemView")
        }

        if let maskItem = selectedMaskableItem {
          ToolbarButton {
            maskItem.toggleMask()
            // Re-run an active search so masked titles re-render highlighted.
            if !appState.history.searchQuery.isEmpty {
              appState.history.searchQuery = appState.history.searchQuery
            }
          } label: {
            Image(systemName: maskItem.isMasked ? "eye" : "eye.slash")
          }
          .shortcutKeyHelp(
            key: maskItem.isMasked ? "UnmaskItem" : "MaskItem",
            tableName: "PreviewItemView"
          )
        }

        ToolbarButton {
          withAnimation {
            appState.togglePin()
          }
        } label: {
          if (appState.navigator.selection.items.allSatisfy { $0.isPinned }) {
            Image(systemName: "pin.slash")
          } else {
            Image(systemName: "pin")
          }
        }
        .shortcutKeyHelp(
          name: .pin,
          key: shouldUnpin ? "UnpinKey" : "PinKey",
          tableName: "PreviewItemView",
          replacementKey: "pinKey"
        )
        .disabled(pinActionDisabled)

        ToolbarButton {
          appState.deleteSelection()
        } label: {
          Image(systemName: "trash")
        }
        .shortcutKeyHelp(
          name: .delete,
          key: "DeleteKey",
          tableName: "PreviewItemView",
          replacementKey: "deleteKey"
        )
      }

      if appState.navigator.pasteStackSelected {
        ToolbarButton {
          appState.removePasteStack()
        } label: {
          Image(systemName: "stop")
        }
        .accessibilityLabel(Text("toolbar_remove_paste_stack_action"))
      }

      if alignLeft {
        Spacer()
      }
    }
  }
}
