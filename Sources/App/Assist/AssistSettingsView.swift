import Foundation
import Shared
import SwiftUI

// MARK: - Settings View

@available(iOS 26.0, *)
struct AssistSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("enableAssistOnDeviceSTT") private var enableOnDeviceSTT = false
    @AppStorage("enableAssistModernUI") private var enableModernUI = false
    @AppStorage("assistModernUITheme") private var selectedThemeRawValue = ModernAssistTheme.homeAssistant.rawValue

    private var selectedTheme: Binding<ModernAssistTheme> {
        Binding(
            get: { ModernAssistTheme(rawValue: selectedThemeRawValue) ?? .homeAssistant },
            set: { selectedThemeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(L10n.Assist.Settings.OnDeviceStt.toggle, isOn: $enableOnDeviceSTT)
                } footer: {
                    Text(L10n.Assist.Settings.OnDeviceStt.footer)
                }

                Section {
                    Toggle(L10n.Assist.Settings.ModernUi.toggle, isOn: $enableModernUI)

                    if enableModernUI {
                        Picker(L10n.Assist.Settings.ModernUi.Theme.label, selection: selectedTheme) {
                            ForEach(ModernAssistTheme.allCases) { theme in
                                Text(theme.rawValue)
                                    .tag(theme)
                            }
                        }
                    }
                } header: {
                    Label(L10n.Assist.Settings.header, systemSymbol: .flaskFill)
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
