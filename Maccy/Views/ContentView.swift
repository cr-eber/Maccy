import Defaults
import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @Default(.backgroundOpacity) private var backgroundOpacity

  @Environment(\.colorScheme) private var colorScheme

  @FocusState private var searchFocused: Bool

  private var solidBackground: Color {
    colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : .white
  }

  var body: some View {
    ZStack {
      #if compiler(>=6.2)
      if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }
      #else
      VisualEffectView()
      #endif

      // Solid backdrop over the blur: at 100% nothing behind the window
      // shows through (pure white in light mode).
      solidBackground
        .opacity(backgroundOpacity)

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        VStack(spacing: 0) {
          SlideoutView(controller: appState.preview) {
            HeaderView(
              controller: appState.preview,
              searchFocused: $searchFocused
            )

            VStack(alignment: .leading, spacing: 0) {
              HistoryListView(
                searchQuery: $appState.history.searchQuery,
                searchFocused: $searchFocused
              )
            }
            .animation(.default.speed(3), value: appState.history.items)
            .animation(
              .default.speed(3),
              value: appState.history.pasteStack?.id
            )
            .onAppear {
              searchFocused = true
            }
            .onMouseMove {
              appState.navigator.isKeyboardNavigating = false
            }
          } slideout: {
            SlideoutContentView()
          }
          .frame(minHeight: 0)
          .layoutPriority(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
