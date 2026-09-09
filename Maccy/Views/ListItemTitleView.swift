import SwiftUI

struct ListItemTitleView<Title: View>: View {
  static var maxLines: Int { 3 }

  var attributedTitle: AttributedString?
  @ViewBuilder var title: () -> Title

  var body: some View {
    if let attributedTitle {
      Text(attributedTitle)
        .accessibilityIdentifier("copy-history-item")
        .lineLimit(Self.maxLines)
        .truncationMode(.tail)
    } else {
      title()
        .accessibilityIdentifier("copy-history-item")
        .lineLimit(Self.maxLines)
        .truncationMode(.middle)
        // Workaround for macOS 26 to avoid flipped text
        // https://github.com/p0deje/Maccy/issues/1113
        .drawingGroup()
    }
  }
}
