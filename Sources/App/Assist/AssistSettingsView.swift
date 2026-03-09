import Foundation
import Shared
import SwiftUI

#if canImport(SpeechTranscriber)
import SpeechTranscriber
#endif

// MARK: - Settings View

@available(iOS 26.0, *)
struct AssistSettingsView: View {
    @StateObject private var viewModel = AssistSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var supportedLocales: [Locale] {
        #if canImport(SpeechTranscriber)
        SpeechTranscriber.supportedLocales
        #else
        []
        #endif
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
                Section {
                    Toggle(L10n.Assist.Settings.TtsMute.toggle, isOn: $viewModel.configuration.muteTTS)
                } footer: {
                    Text(L10n.Assist.Settings.TtsMute.footer)
                }

                Section("Experimental") {
                    Toggle("On-device STT", isOn: $viewModel.configuration.enableOnDeviceSTT)

                    if viewModel.configuration.enableOnDeviceSTT, !supportedLocales.isEmpty {
                        Picker("Language", selection: onDeviceSTTLocaleBinding) {
                            ForEach(supportedLocales, id: \.identifier) { locale in
                                Text(localeDisplayName(locale))
                                    .tag(locale.identifier)
                            }
                        }
                    }
                }
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
}
