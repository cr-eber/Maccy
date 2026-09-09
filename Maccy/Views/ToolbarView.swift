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
  @Default(.previewPinned) private var previewPinned

  @Namespace var unionNamespace

  enum Section: Hashable {
    case itemOptions
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

  var body: some View {
    HStack {
      if !appState.navigator.selection.isEmpty {
        Spacer()

        if selectedImageItem != nil {
          ToolbarButton {
            scanQRCode()
          } label: {
            Image(systemName: "qrcode.viewfinder")
          }
          .shortcutKeyHelp(key: "ScanQRCode", tableName: "PreviewItemView")
        }

        ToolbarButton {
          appState.togglePin()
        } label: {
          Image(systemName: previewPinned ? "pin.fill" : "pin")
        }
        .shortcutKeyHelp(
          name: .pin,
          key: previewPinned ? "UnpinKey" : "PinKey",
          tableName: "PreviewItemView",
          replacementKey: "pinKey"
        )

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
    }
  }
}
