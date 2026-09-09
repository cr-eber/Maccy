import Defaults
import SwiftUI

struct ListItemTitleView<Title: View>: View {
  var attributedTitle: AttributedString?
  // Overrides the configured lines-per-item (e.g. pinned rows are 1 line).
  var lineLimitOverride: Int?
  @ViewBuilder var title: () -> Title

  @Default(.maxItemLines) private var maxItemLines

  private var lineLimit: Int {
    lineLimitOverride ?? maxItemLines
  }

  var body: some View {
    if let attributedTitle {
      Text(attributedTitle)
        .accessibilityIdentifier("copy-history-item")
        .lineLimit(lineLimit)
        .truncationMode(.tail)
    } else {
      title()
        .accessibilityIdentifier("copy-history-item")
        .lineLimit(lineLimit)
        .truncationMode(.middle)
        // Workaround for macOS 26 to avoid flipped text
        // https://github.com/p0deje/Maccy/issues/1113
        .drawingGroup()
    }
  }
}
