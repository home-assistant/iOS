import AVFoundation
import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

// MARK: - Settings View

struct AssistSettingsView: View {
    @StateObject private var viewModel = AssistSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var supportedSTTLocales: [Locale] {
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
                    ?? supportedSTTLocales.first?.identifier
                    ?? Locale.current.identifier
            },
            set: { newValue in
                viewModel.configuration.onDeviceSTTLocaleIdentifier = newValue
            }
        )
    }

    private var selectedVoiceDisplayName: String {
        guard let id = viewModel.configuration.onDeviceTTSVoiceIdentifier,
              let voice = AVSpeechSynthesisVoice(identifier: id) else {
            return L10n.Assist.Settings.OnDeviceTts.defaultVoice
        }
        return voice.name
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
                guard isEnabled, !supportedSTTLocales.isEmpty else { return }
                let supportedIdentifiers = Set(supportedSTTLocales.map(\.identifier))
                let currentIdentifier = viewModel.configuration.onDeviceSTTLocaleIdentifier
                if currentIdentifier == nil || !supportedIdentifiers.contains(currentIdentifier ?? "") {
                    viewModel.configuration.onDeviceSTTLocaleIdentifier = supportedSTTLocales.first?.identifier
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
            Toggle(isOn: $viewModel.configuration.muteTTS, label: {
                toggleLabel(symbol: .speakerSlashFill, text: L10n.Assist.Settings.TtsMute.toggle)
            })
        } footer: {
            Text(L10n.Assist.Settings.TtsMute.footer)
        }
    }

    @ViewBuilder
    private var experimental: some View {
        if #available(iOS 17.0, *) {
            Section {
                Toggle(isOn: $viewModel.configuration.enableOnDeviceSTT) {
                    toggleLabel(symbol: .micFill, text: L10n.Assist.Settings.OnDeviceStt.title)
                }

                if viewModel.configuration.enableOnDeviceSTT, !supportedSTTLocales.isEmpty {
                    Picker(L10n.Assist.Settings.OnDeviceStt.language, selection: onDeviceSTTLocaleBinding) {
                        ForEach(supportedSTTLocales, id: \.identifier) { locale in
                            Text(localeDisplayName(locale).capitalizedFirst)
                                .tag(locale.identifier)
                        }
                    }
                }

                Toggle(isOn: $viewModel.configuration.enableOnDeviceTTS) {
                    toggleLabel(symbol: .speakerWave2Fill, text: L10n.Assist.Settings.OnDeviceTts.title)
                }

                if viewModel.configuration.enableOnDeviceTTS {
                    NavigationLink {
                        TTSVoicePickerView(selectedVoiceIdentifier: $viewModel.configuration.onDeviceTTSVoiceIdentifier)
                    } label: {
                        HStack {
                            Text(L10n.Assist.Settings.OnDeviceTts.voice)
                            Spacer()
                            Text(selectedVoiceDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(L10n.Assist.Settings.Section.Experimental.title)
            } footer: {
                if viewModel.configuration.enableOnDeviceTTS {
                    Text(L10n.Assist.Settings.OnDeviceTts.footer)
                }
            }
        }
    }

    private func toggleLabel(symbol: SFSymbol, text: String) -> some View {
        HStack {
            Image(systemSymbol: symbol)
                .frame(width: 24, height: 24)
            Text(text)
        }
    }
}
