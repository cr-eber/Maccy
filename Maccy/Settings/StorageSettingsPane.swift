import SwiftUI
import Defaults
import Settings

struct StorageSettingsPane: View {
  @Observable
  class ViewModel {
    var saveFiles = false {
      didSet {
        Defaults.withoutPropagation {
          if saveFiles {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.files.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.files.types)
          }
        }
      }
    }

    var saveImages = false {
      didSet {
        Defaults.withoutPropagation {
          if saveImages {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.images.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.images.types)
          }
        }
      }
    }

    var saveText = false {
      didSet {
        Defaults.withoutPropagation {
          if saveText {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.text.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.text.types)
          }
        }
      }
    }

    private var observer: Defaults.Observation?

    init() {
      observer = Defaults.observe(.enabledPasteboardTypes) { change in
        self.saveFiles = change.newValue.isSuperset(of: StorageType.files.types)
        self.saveImages = change.newValue.isSuperset(of: StorageType.images.types)
        self.saveText = change.newValue.isSuperset(of: StorageType.text.types)
      }
    }

    deinit {
      observer?.invalidate()
    }
  }

  @Default(.size) private var size
  @Default(.sortBy) private var sortBy

  @State private var viewModel = ViewModel()
  @State private var storageSize = Storage.shared.size
  @State private var showClearConfirmation = false
  @State private var confirmationClearsAll = false

  private let sizeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 100_000
    return formatter
  }()

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("Save", tableName: "StorageSettings") }
      ) {
        Toggle(
          isOn: $viewModel.saveFiles,
          label: { Text("Files", tableName: "StorageSettings") }
        )
        Toggle(
          isOn: $viewModel.saveImages,
          label: { Text("Images", tableName: "StorageSettings") }
        )
        Toggle(
          isOn: $viewModel.saveText,
          label: { Text("Text", tableName: "StorageSettings") }
        )
        Text("SaveDescription", tableName: "StorageSettings")
          .controlSize(.small)
          .foregroundStyle(.gray)
      }

      Settings.Section(label: { Text("Size", tableName: "StorageSettings") }) {
        HStack {
          TextField("", value: $size, formatter: sizeFormatter)
            .frame(width: 80)
            .help(Text("SizeTooltip", tableName: "StorageSettings"))
            .accessibilityLabel(Text("Size", tableName: "StorageSettings"))
          Stepper("", value: $size, in: 1...100_000)
            .labelsHidden()
            .accessibilityLabel(Text("Size", tableName: "StorageSettings"))
          Text(storageSize)
            .controlSize(.small)
            .foregroundStyle(.gray)
            .help(Text("CurrentSizeTooltip", tableName: "StorageSettings"))
            .onAppear {
              storageSize = Storage.shared.size
            }
        }
      }

      Settings.Section(label: { Text("SortBy", tableName: "StorageSettings") }) {
        Picker("", selection: $sortBy) {
          ForEach(Sorter.By.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .frame(width: 160, alignment: .leading)
        .help(Text("SortByTooltip", tableName: "StorageSettings"))
        .accessibilityLabel(Text("SortBy", tableName: "StorageSettings"))
      }

      Settings.Section(label: { Text("ClearHistory", tableName: "StorageSettings") }) {
        HStack {
          Button {
            confirmationClearsAll = false
            showClearConfirmation = true
          } label: {
            Text(LocalizedStringKey("clear"))
          }
          .help(Text(LocalizedStringKey("clear_tooltip")))

          Button(role: .destructive) {
            confirmationClearsAll = true
            showClearConfirmation = true
          } label: {
            Text(LocalizedStringKey("clear_all"))
          }
          .help(Text(LocalizedStringKey("clear_all_tooltip")))
        }
        .confirmationDialog(
          Text(LocalizedStringKey("clear_alert_message")),
          isPresented: $showClearConfirmation
        ) {
          Button(LocalizedStringKey("clear_alert_confirm"), role: .destructive) {
            if confirmationClearsAll {
              AppState.shared.history.clearAll()
            } else {
              AppState.shared.history.clear()
            }
          }
          Button(LocalizedStringKey("clear_alert_cancel"), role: .cancel) {}
        } message: {
          Text(LocalizedStringKey("clear_alert_comment"))
        }
      }
    }
  }
}

#Preview {
  StorageSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
