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
                    Toggle(
                        L10n.Assist.Settings.OnDeviceStt.toggle,
                        isOn: $viewModel.configuration.enableOnDeviceSTT
                    )

                    if viewModel.configuration.enableOnDeviceSTT {
                        Picker(
                            L10n.Assist.Settings.OnDeviceStt.Language.label,
                            selection: $viewModel.configuration.sttLanguage
                        ) {
                            Text(L10n.Assist.Settings.OnDeviceStt.Language.deviceDefault)
                                .tag("")
                            ForEach(viewModel.availableLanguages, id: \.self) { localeId in
                                Text(viewModel.displayName(for: localeId))
                                    .tag(localeId)
                            }
                        }

                        if !viewModel.isSelectedLanguageSupported {
                            Label(
                                L10n.Assist.Settings.OnDeviceStt.Language.notSupported,
                                systemSymbol: .exclamationmarkTriangleFill
                            )
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        }
                    }
                } footer: {
                    Text(L10n.Assist.Settings.OnDeviceStt.footer)
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
