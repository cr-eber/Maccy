import Defaults
import SwiftUI

struct HeaderView: View {
  @State private var appState = AppState.shared
  @State private var settingsMenuShown = false

  let controller: SlideoutController
  @FocusState.Binding var searchFocused: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      // The settings icon overlays the trailing edge of the full-width search box.
      ZStack(alignment: .trailing) {
        ListHeaderView(
          searchFocused: $searchFocused,
          searchQuery: $appState.history.searchQuery
        )

        ToolbarButton {
          settingsMenuShown.toggle()
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel(Text(LocalizedStringKey("preferences")))
        .popover(isPresented: $settingsMenuShown, arrowEdge: .bottom) {
          // Clearing history lives in Preferences > Storage.
          VStack(alignment: .leading, spacing: 2) {
            ForEach(appState.footer.items.filter { ["preferences", "quit"].contains($0.title) }) { item in
              FooterItemView(item: item)
            }
          }
          .padding(6)
          .frame(width: 220)
        }
        .padding(.trailing, 8)
      }
      .opacity(appState.searchVisible ? 1 : 0)
      .accessibilityHidden(!appState.searchVisible)
      .layoutPriority(1)
    }
    .animation(.default.speed(3), value: appState.navigator.leadSelection)
    .background(.clear)
    .frame(maxHeight: !appState.searchVisible ? 0 : nil, alignment: .top)
    .readHeight(appState, into: \.popup.headerHeight)
  }
}
