import Foundation
import Shared
import SwiftUI

// MARK: - Settings View

@available(iOS 26.0, *)
struct AssistSettingsView: View {
    @StateObject private var viewModel = AssistSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var supportedLocales: [Locale] {
        if #available(iOS 17.0, *) {
            return SpeechTranscriber.supportedLocales
        } else {
            return []
        }
    }

    private var onDeviceSTTLocaleBinding: Binding<String> {
        Binding(
            get: {
                viewModel.configuration.onDeviceSTTLocaleIdentifier
                    ?? supportedLocales.first?.identifier
                    ?? Locale.current.identifier
            },
            set: { newValue in
                viewModel.configuration.onDeviceSTTLocaleIdentifier = newValue
            }
        )
    }

    private func localeDisplayName(_ locale: Locale) -> String {
        locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    var body: some View {
        NavigationView {
            Form {
                muteToggle
                experimental
            }
            .onChange(of: viewModel.configuration.enableOnDeviceSTT) { isEnabled in
                guard isEnabled, !supportedLocales.isEmpty else { return }
                let supportedIdentifiers = Set(supportedLocales.map(\.identifier))
                let currentIdentifier = viewModel.configuration.onDeviceSTTLocaleIdentifier
                if currentIdentifier == nil || !supportedIdentifiers.contains(currentIdentifier ?? "") {
                    viewModel.configuration.onDeviceSTTLocaleIdentifier = supportedLocales.first?.identifier
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

    private var muteToggle: some View {
        Section {
            Toggle(L10n.Assist.Settings.TtsMute.toggle, isOn: $viewModel.configuration.muteTTS)
        } footer: {
            Text(L10n.Assist.Settings.TtsMute.footer)
        }
    }

    @ViewBuilder
    private var experimental: some View {
        if #available(iOS 17.0, *) {
            Section(L10n.Assist.Settings.Section.Experimental.title) {
                Toggle(L10n.Assist.Settings.OnDeviceStt.title, isOn: $viewModel.configuration.enableOnDeviceSTT)

                if viewModel.configuration.enableOnDeviceSTT, !supportedLocales.isEmpty {
                    Picker(L10n.Assist.Settings.OnDeviceStt.language, selection: onDeviceSTTLocaleBinding) {
                        ForEach(supportedLocales, id: \.identifier) { locale in
                            Text(localeDisplayName(locale).capitalizedFirst)
                                .tag(locale.identifier)
                        }
                    }
                }
            }
        }
    }
}
