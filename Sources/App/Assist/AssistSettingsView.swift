import Foundation
import Shared
import SwiftUI

// MARK: - Settings View

@available(iOS 26.0, *)
struct AssistSettingsView: View {
    @StateObject private var viewModel = AssistSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(L10n.Assist.Settings.TtsMute.toggle, isOn: $viewModel.configuration.muteTTS)
                } footer: {
                    Text(L10n.Assist.Settings.TtsMute.footer)
                }

                Section {
                    Toggle(L10n.Assist.Settings.ModernUi.toggle, isOn: $viewModel.configuration.enableModernUI)

                    if viewModel.configuration.enableModernUI {
                        Picker(L10n.Assist.Settings.ModernUi.Theme.label, selection: $viewModel.configuration.theme) {
                            ForEach(ModernAssistTheme.allCases) { theme in
                                Text(theme.rawValue)
                                    .tag(theme)
                            }
                        }
                    }
                } header: {
                    Label(L10n.Assist.Settings.Labs.header, systemSymbol: .flaskFill)
                } footer: {
                    Text(L10n.Assist.Settings.ModernUi.footer)
                }
            }
            .navigationTitle(L10n.Assist.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
}
