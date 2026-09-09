import Defaults
import SwiftUI

struct ListItemTitleView<Title: View>: View {
  var attributedTitle: AttributedString?
  @ViewBuilder var title: () -> Title

  @Default(.maxItemLines) private var maxItemLines

  var body: some View {
    if let attributedTitle {
      Text(attributedTitle)
        .accessibilityIdentifier("copy-history-item")
        .lineLimit(maxItemLines)
        .truncationMode(.tail)
    } else {
      title()
        .accessibilityIdentifier("copy-history-item")
        .lineLimit(maxItemLines)
        .truncationMode(.middle)
        // Workaround for macOS 26 to avoid flipped text
        // https://github.com/p0deje/Maccy/issues/1113
        .drawingGroup()
    }
  }
}
