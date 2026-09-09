import AppKit
import Defaults

enum AppearanceMode: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
  case system
  case light
  case dark

  var id: Self { self }

  var description: String {
    switch self {
    case .system:
      return NSLocalizedString("AppearanceModeSystem", tableName: "AppearanceSettings", comment: "")
    case .light:
      return NSLocalizedString("AppearanceModeLight", tableName: "AppearanceSettings", comment: "")
    case .dark:
      return NSLocalizedString("AppearanceModeDark", tableName: "AppearanceSettings", comment: "")
    }
  }

  var appearance: NSAppearance? {
    switch self {
    case .system:
      return nil
    case .light:
      return NSAppearance(named: .aqua)
    case .dark:
      return NSAppearance(named: .darkAqua)
    }
  }
}
