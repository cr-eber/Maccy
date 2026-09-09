import SwiftUI

struct MultipleSelectionListView<Element, ID, Content>: View
    where ID: Hashable, Content: View, ID == Element.ID, Element: Identifiable {
  var items: [Element]
  var content: (Element?, Element, Element?, Int) -> Content

  var body: some View {
    LazyVStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { (index, element) in
        let previous = index > 0 ? items[index - 1] : nil
        let next = index < items.count - 1 ? items[index + 1] : nil
        content(previous, element, next, index)

        if next != nil {
          Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, Popup.horizontalSeparatorPadding)
            .padding(.vertical, 3)
        }
      }
    }
  }
}
