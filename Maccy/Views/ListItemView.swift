import Defaults
import SwiftHEXColors
import SwiftUI

enum SelectionAppearance {
  case none
  case topConnection
  case bottomConnection
  case topBottomConnection

  func rect(cornerRadius: CGFloat) -> some Shape {
    var cornerRadii = RectangleCornerRadii()
    switch self {
    case .none:
      cornerRadii.topLeading = cornerRadius
      cornerRadii.topTrailing = cornerRadius
      cornerRadii.bottomLeading = cornerRadius
      cornerRadii.bottomTrailing = cornerRadius
    case .topConnection:
      cornerRadii.bottomLeading = cornerRadius
      cornerRadii.bottomTrailing = cornerRadius
    case .bottomConnection:
      cornerRadii.topLeading = cornerRadius
      cornerRadii.topTrailing = cornerRadius
    case .topBottomConnection:
      break
    }
    return .rect(cornerRadii: cornerRadii)
  }
}

struct ListItemView<Title: View, ID: Hashable>: View {
  var id: ID
  var selectionId: UUID
  var appIcon: ApplicationImage?
  var image: NSImage?
  var accessoryImage: NSImage?
  var attributedTitle: AttributedString?
  var shortcuts: [KeyShortcut]
  var isSelected: Bool
  var selectionIndex: Int?
  var help: LocalizedStringKey?
  var selectionAppearance: SelectionAppearance = .none
  // Row index used for the alternating (zebra) background; nil disables striping.
  var stripeIndex: Int?
  // Complete description used when the row's visual content is hidden from accessibility.
  var accessibilityLabel: String = ""
  @ViewBuilder var title: () -> Title

  @Default(.maxItemLines) private var maxItemLines
  @Default(.selectionColor) private var selectionColor
  @Default(.showApplicationIcons) private var showIcons
  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags

  // Use the same selection number for the visible badge and accessibility value.
  private var displaySelectionIndex: String? {
    selectionIndex.map { "\($0 + 1)" }
  }

  private var stripeColor: Color {
    if let stripeIndex, !stripeIndex.isMultiple(of: 2) {
      return Color.primary.opacity(0.09)
    }
    // macOS 26 broke hovering if no background is present.
    // The slight opacity white background is a workaround
    return Color.white.opacity(0.001)
  }

  private var selectionNSColor: NSColor {
    NSColor(hexString: selectionColor) ?? .controlAccentColor
  }

  // Black text on light selection colors, white text on dark ones.
  private var selectedForeground: Color {
    let srgb = selectionNSColor.usingColorSpace(.sRGB) ?? .white
    let luminance = 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
    return luminance < 0.5 ? .white : .black
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      if showIcons, let appIcon {
        AppImageView(appImage: appIcon, size: NSSize(width: 15, height: 15))
          .padding(.leading, 4)
          .padding(.top, Popup.itemVerticalInset + 1)
      }

      Spacer()
        .frame(width: showIcons ? 5 : 10)

      if let accessoryImage {
        Image(nsImage: accessoryImage)
          .accessibilityIdentifier("copy-history-item")
          .accessibilityHidden(true)
          .padding(.trailing, 5)
          .padding(.top, Popup.itemVerticalInset)
      }

      if let image {
        Image(nsImage: image)
          .accessibilityIdentifier("copy-history-item")
          .accessibilityHidden(true)
          .padding(.trailing, 5)
          .padding(.vertical, 5)
      } else if stripeIndex != nil {
        // History rows have a uniform height; top-align the text within it.
        VStack(spacing: 0) {
          ListItemTitleView(attributedTitle: attributedTitle, title: title)
          Spacer(minLength: 0)
        }
        .padding(.top, Popup.itemVerticalInset)
        .accessibilityHidden(true)
        .padding(.trailing, 5)
      } else {
        ListItemTitleView(attributedTitle: attributedTitle, title: title)
          .accessibilityHidden(true)
          .padding(.trailing, 5)
      }

      Spacer()

      HStack(spacing: 5) {
        if let displaySelectionIndex {
          Text(displaySelectionIndex)
            .font(.caption)
            .frame(minWidth: 10, alignment: .center)
            .padding(3)
            .background(
              Color.secondary.opacity(isSelected ? 0.5 : 0.8),
              in: Capsule()
            )
            .foregroundStyle(Color.white)
            .accessibilityHidden(true)
        }

        if !shortcuts.isEmpty {
          ZStack(alignment: .trailing) {
            ForEach(shortcuts) { shortcut in
              let visible = shortcut.isVisible(shortcuts, modifierFlags.flags)
              KeyboardShortcutView(shortcut: shortcut)
                .opacity(visible ? 1 : 0)
                .accessibilityHidden(true)
                .frame(width: visible ? nil : 0)
            }
          }
        }
      }
      .padding(.trailing, 10)
    }
    // Only history rows (striped) get the uniform multi-line height;
    // footer and paste stack rows keep the compact single-line height.
    .frame(height: stripeIndex != nil ? Popup.itemHeight(lines: maxItemLines) : nil)
    .frame(minHeight: Popup.itemHeight)
    .clipped()
    .id(id)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(isSelected ? selectedForeground : .primary)
    .background {
      // Selection keeps rounded corners; the zebra stripe stays square.
      if isSelected {
        selectionAppearance.rect(cornerRadius: Popup.cornerRadius)
          .fill(Color(nsColor: selectionNSColor))
      } else {
        stripeColor
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(accessibilityLabel))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityValue(Text(displaySelectionIndex ?? ""))
    .hoverSelectionId(selectionId)
    .help(help ?? "")
  }
}
