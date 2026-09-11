import AppKit
import SwiftUI
import Defaults
import Settings
import SwiftHEXColors

struct AppearanceSettingsPane: View {
  @Default(.appearanceMode) private var appearanceMode
  @Default(.backgroundOpacity) private var backgroundOpacity
  @Default(.fontSize) private var fontSize
  @Default(.popupHeightPercent) private var popupHeightPercent
  @Default(.previewWidth) private var previewWidth
  @Default(.windowSize) private var windowSize

  // Continuous sliders rounded to 10pt; a step would draw dozens of ticks.
  private var popupWidthBinding: Binding<Double> {
    Binding {
      windowSize.width
    } set: {
      windowSize.width = ($0 / 10).rounded() * 10
    }
  }

  private var previewWidthBinding: Binding<Double> {
    Binding {
      previewWidth
    } set: {
      previewWidth = ($0 / 10).rounded() * 10
    }
  }

  private var popupHeightPercentBinding: Binding<Double> {
    Binding {
      popupHeightPercent
    } set: {
      popupHeightPercent = ($0 / 0.05).rounded() * 0.05
    }
  }
  @Default(.itemGap) private var itemGap
  @Default(.maskPrefixLength) private var maskPrefixLength
  @Default(.maskSuffixLength) private var maskSuffixLength
  @Default(.maxItemLines) private var maxItemLines
  @Default(.popupPosition) private var popupAt
  @Default(.popupScreen) private var popupScreen
  @Default(.pinTo) private var pinTo
  @Default(.imageMaxHeight) private var imageHeight
  @Default(.openPreviewAutomatically) private var openPreviewAutomatically
  @Default(.previewDelay) private var previewDelay
  @Default(.highlightMatch) private var highlightMatch
  @Default(.highlightMatchColor) private var highlightMatchColor
  @Default(.selectionColor) private var selectionColor

  private func hexColorBinding(_ hex: Binding<String>) -> Binding<Color> {
    Binding {
      Color(nsColor: NSColor(hexString: hex.wrappedValue) ?? .gray)
    } set: { newValue in
      guard let srgb = NSColor(newValue).usingColorSpace(.sRGB) else { return }
      hex.wrappedValue = String(
        format: "#%02X%02X%02X",
        Int(round(srgb.redComponent * 255)),
        Int(round(srgb.greenComponent * 255)),
        Int(round(srgb.blueComponent * 255))
      )
    }
  }
  @Default(.menuIcon) private var menuIcon
  @Default(.showInStatusBar) private var showInStatusBar
  @Default(.showSearch) private var showSearch
  @Default(.searchVisibility) private var searchVisibility
  @Default(.showFooter) private var showFooter
  @Default(.windowPosition) private var windowPosition
  @Default(.showApplicationIcons) private var showApplicationIcons

  @State private var screens = NSScreen.screens

  private let imageHeightFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 200
    return formatter
  }()

  private let numberOfItemsFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 0
    formatter.maximum = 100
    return formatter
  }()

  private let titleLengthFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 30
    formatter.maximum = 200
    return formatter
  }()

  private let previewDelayFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 200
    formatter.maximum = 100_000
    return formatter
  }()

  var body: some View {
    Settings.Container(contentWidth: 650) {
      Settings.Section(label: { Text("AppearanceMode", tableName: "AppearanceSettings") }) {
        Picker("", selection: $appearanceMode) {
          ForEach(AppearanceMode.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .frame(width: 180)
        .help(Text("AppearanceModeTooltip", tableName: "AppearanceSettings"))
        .accessibilityLabel(Text("AppearanceMode", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("BackgroundOpacity", tableName: "AppearanceSettings") }) {
        HStack {
          Slider(value: $backgroundOpacity, in: 0.1...1.0)
            .frame(width: 180)
            .accessibilityLabel(Text("BackgroundOpacity", tableName: "AppearanceSettings"))
          Text(verbatim: "\(Int(backgroundOpacity * 100))%")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .frame(width: 40, alignment: .leading)
        }
        .help(Text("BackgroundOpacityTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("FontSize", tableName: "AppearanceSettings") }) {
        HStack {
          Slider(value: $fontSize, in: 10...24, step: 1)
            .frame(width: 180)
            .accessibilityLabel(Text("FontSize", tableName: "AppearanceSettings"))
          Text(verbatim: "\(Int(fontSize)) pt")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .frame(width: 40, alignment: .leading)
        }
        .help(Text("FontSizeTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("PopupHeight", tableName: "AppearanceSettings") }) {
        HStack {
          Slider(value: popupHeightPercentBinding, in: 0.2...1.0)
            .frame(width: 180)
            .accessibilityLabel(Text("PopupHeight", tableName: "AppearanceSettings"))
          Text(verbatim: "\(Int(round(popupHeightPercent * 100)))%")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .frame(width: 40, alignment: .leading)
        }
        .help(Text("PopupHeightTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("PopupWidth", tableName: "AppearanceSettings") }) {
        HStack {
          Slider(value: popupWidthBinding, in: 250...800)
            .frame(width: 180)
            .accessibilityLabel(Text("PopupWidth", tableName: "AppearanceSettings"))
          Text(verbatim: "\(Int(windowSize.width)) pt")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .frame(width: 50, alignment: .leading)
        }
        .help(Text("PopupWidthTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("PreviewWidth", tableName: "AppearanceSettings") }) {
        HStack {
          Slider(value: previewWidthBinding, in: 200...800)
            .frame(width: 180)
            .accessibilityLabel(Text("PreviewWidth", tableName: "AppearanceSettings"))
          Text(verbatim: "\(Int(previewWidth)) pt")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .frame(width: 50, alignment: .leading)
        }
        .help(Text("PreviewWidthTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("MaxItemLines", tableName: "AppearanceSettings") }) {
        HStack {
          Text(verbatim: "\(maxItemLines)")
            .frame(width: 20, alignment: .leading)
          Stepper("", value: $maxItemLines, in: 1...10)
            .labelsHidden()
            .accessibilityLabel(Text("MaxItemLines", tableName: "AppearanceSettings"))
        }
        .help(Text("MaxItemLinesTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("ItemGap", tableName: "AppearanceSettings") }) {
        HStack {
          Slider(value: $itemGap, in: 0...30, step: 1)
            .frame(width: 180)
            .accessibilityLabel(Text("ItemGap", tableName: "AppearanceSettings"))
          Text(verbatim: "\(Int(itemGap))")
            .controlSize(.small)
            .foregroundStyle(.gray)
            .frame(width: 30, alignment: .leading)
        }
        .help(Text("ItemGapTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("MaskReveal", tableName: "AppearanceSettings") }) {
        HStack {
          Text("MaskRevealFirst", tableName: "AppearanceSettings")
          Text(verbatim: "\(maskPrefixLength)")
          Stepper("", value: $maskPrefixLength, in: 0...20)
            .labelsHidden()
            .accessibilityLabel(Text("MaskRevealFirst", tableName: "AppearanceSettings"))
          Text("MaskRevealLast", tableName: "AppearanceSettings")
          Text(verbatim: "\(maskSuffixLength)")
          Stepper("", value: $maskSuffixLength, in: 0...20)
            .labelsHidden()
            .accessibilityLabel(Text("MaskRevealLast", tableName: "AppearanceSettings"))
        }
        .help(Text("MaskRevealTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("SelectionColor", tableName: "AppearanceSettings") }) {
        ColorPicker("", selection: hexColorBinding($selectionColor), supportsOpacity: false)
          .labelsHidden()
          .help(Text("SelectionColorTooltip", tableName: "AppearanceSettings"))
          .accessibilityLabel(Text("SelectionColor", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("PopupAt", tableName: "AppearanceSettings") }) {
        HStack {
          Picker("", selection: $popupAt) {
            ForEach(PopupPosition.allCases) { position in
              if position == .center || position == .lastPosition, screens.count > 1 {
                screenPicker(for: position)
              } else {
                Text(position.description)
              }
            }
          }
          .labelsHidden()
          .frame(width: 141, alignment: .leading)
          .help(Text("PopupAtTooltip", tableName: "AppearanceSettings"))
          .accessibilityLabel(Text("PopupAt", tableName: "AppearanceSettings"))

          if popupAt == .lastPosition {
            Button {
              _windowPosition.reset()
            } label: {
              Image(systemName: "arrow.uturn.backward.circle.fill")
                .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .help(Text("PopupAtLastLocationReset", tableName: "AppearanceSettings"))
            .disabled(windowPosition == _windowPosition.defaultValue)
          }
        }
      }

      Settings.Section(label: { Text("PinTo", tableName: "AppearanceSettings") }) {
        Picker("", selection: $pinTo) {
          ForEach(PinsPosition.allCases) { position in
            Text(position.description)
          }
        }
        .labelsHidden()
        .frame(width: 141, alignment: .leading)
        .help(Text("PinToTooltip", tableName: "AppearanceSettings"))
        .accessibilityLabel(Text("PinTo", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("ImageHeight", tableName: "AppearanceSettings") }) {
        HStack {
          TextField("", value: $imageHeight, formatter: imageHeightFormatter)
            .frame(width: 120)
            .help(Text("ImageHeightTooltip", tableName: "AppearanceSettings"))
            .accessibilityLabel(Text("ImageHeight", tableName: "AppearanceSettings"))
          Stepper("", value: $imageHeight, in: 1...200)
            .labelsHidden()
            .accessibilityLabel(Text("ImageHeight", tableName: "AppearanceSettings"))
        }
      }

      Settings.Section(title: "") {
        Defaults.Toggle(key: .openPreviewAutomatically) {
          Text("OpenPreviewAutomatically", tableName: "AppearanceSettings")
        }
        Defaults.Toggle(key: .previewPinned) {
          Text("PinPreview", tableName: "AppearanceSettings")
        }
        .help(Text("PinPreviewTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("PreviewDelay", tableName: "AppearanceSettings") }) {
        HStack {
          TextField("", value: $previewDelay, formatter: previewDelayFormatter)
            .frame(width: 120)
            .help(Text("PreviewDelayTooltip", tableName: "AppearanceSettings"))
            .accessibilityLabel(Text("PreviewDelay", tableName: "AppearanceSettings"))
          Stepper("", value: $previewDelay, in: 200...100_000)
            .labelsHidden()
            .accessibilityLabel(Text("PreviewDelay", tableName: "AppearanceSettings"))
        }
        .disabled(!openPreviewAutomatically)
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("HighlightMatches", tableName: "AppearanceSettings") }
      ) {
        HStack {
          Picker("", selection: $highlightMatch) {
            ForEach(HighlightMatch.allCases) { match in
              Text(match.description)
            }
          }
          .labelsHidden()
          .frame(width: 141, alignment: .leading)
          .help(Text("HighlightMatchesTooltip", tableName: "AppearanceSettings"))
          .accessibilityLabel(Text("HighlightMatches", tableName: "AppearanceSettings"))

          if highlightMatch == .coloredText {
            ColorPicker("", selection: hexColorBinding($highlightMatchColor), supportsOpacity: false)
              .labelsHidden()
              .accessibilityLabel(Text("HighlightMatchColoredText", tableName: "AppearanceSettings"))
          }
        }
      }

      Settings.Section(title: "") {
        Defaults.Toggle(key: .showSpecialSymbols) {
          Text("ShowSpecialSymbols", tableName: "AppearanceSettings")
        }
        .help(Text("ShowSpecialSymbolsTooltip", tableName: "AppearanceSettings"))

        HStack {
          Defaults.Toggle(key: .showInStatusBar) {
            Text("ShowMenuIcon", tableName: "AppearanceSettings")
          }

          Picker("", selection: $menuIcon) {
            ForEach(MenuIcon.allCases) { icon in
              Image(nsImage: icon.image)
            }
          }
          .labelsHidden()
          .scaledToFit()
          .disabled(!showInStatusBar)
          .controlSize(.small)
          .accessibilityLabel(Text("ShowMenuIcon", tableName: "AppearanceSettings"))
        }

        Defaults.Toggle(key: .showRecentCopyInMenuBar) {
          Text("ShowRecentCopyInMenuBar", tableName: "AppearanceSettings")
        }
        HStack {
          Defaults.Toggle(key: .showSearch) {
            Text("ShowSearchField", tableName: "AppearanceSettings")
          }

          Picker("", selection: $searchVisibility) {
            ForEach(SearchVisibility.allCases) { type in
              Text(type.description)
            }
          }
          .labelsHidden()
          .scaledToFit()
          .disabled(!showSearch)
          .controlSize(.small)
          .accessibilityLabel(Text("ShowSearchField", tableName: "AppearanceSettings"))
        }
        Defaults.Toggle(key: .showTitle) {
          Text("ShowTitleBeforeSearchField", tableName: "AppearanceSettings")
        }
        Defaults.Toggle(key: .showApplicationIcons) {
          Text("ShowApplicationIcons", tableName: "AppearanceSettings")
        }
        Defaults.Toggle(key: .showHexColorSwatch) {
          Text("ShowHexColorSwatch", tableName: "AppearanceSettings")
        }
        .help(Text("ShowHexColorSwatchTooltip", tableName: "AppearanceSettings"))

        Defaults.Toggle(key: .showFooter) {
          Text("ShowFooter", tableName: "AppearanceSettings")
        }
        Text("OpenPreferencesWarning", tableName: "AppearanceSettings")
          .fixedSize(horizontal: false, vertical: true)
          .opacity(showFooter ? 0 : 1)
          .controlSize(.small)
          .foregroundStyle(.gray)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
      screens = NSScreen.screens
    }
  }

  @ViewBuilder
  private func screenPicker(for position: PopupPosition) -> some View {
    let screenBinding: Binding<Int> = Binding {
      return popupScreen
    } set: {
      popupScreen = $0
      popupAt = position
    }

    Picker(selection: screenBinding) {
      Text(labelForScreen(index: 0))
        .tag(0)

      ForEach(screens.indices, id: \.self) { index in
        Text(labelForScreen(index: index + 1))
          .tag(index + 1)
      }
    } label: {
      if popupAt == position {
        Text("\(position.description) (\(labelForScreen(index: popupScreen)))")
      } else {
        Text(position.description)
      }
    }
  }

  private func labelForScreen(index screenIndex: Int) -> String {
    switch screenIndex {
    case 0:
      return String(localized: "ActiveScreen", table: "AppearanceSettings")
    case _:
      return screens[screenIndex - 1].localizedName
    }
  }
}

#Preview {
  AppearanceSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
