import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

// MARK: - Settings View

struct AssistSettingsView: View {
    @StateObject private var viewModel = AssistSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    private var onDeviceSTTLocaleBinding: Binding<String> {
        Binding(
            get: {
                viewModel.configuration.onDeviceSTTLocaleIdentifier
                    ?? viewModel.supportedSTTLocales.first?.identifier
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
                startMode
                muteToggle
                labs
            }
            .task {
                await viewModel.loadSupportedSTTLocales()
            }
            .task(id: viewModel.configuration.onDeviceTTSVoiceIdentifier) {
                await viewModel.loadSelectedVoiceDisplayName()
            }
            .onChange(of: viewModel.configuration.enableOnDeviceSTT) { _ in
                viewModel.selectDefaultSTTLocaleIfNeeded()
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

    private var startMode: some View {
        Section {
            Picker(selection: $viewModel.configuration.startMode) {
                ForEach(AssistStartMode.allCases) { mode in
                    Text(mode.localizedTitle)
                        .tag(mode)
                }
            } label: {
                toggleLabel(symbol: .textBubble, text: L10n.Assist.Settings.StartMode.title)
            }
        } footer: {
            Text(L10n.Assist.Settings.StartMode.footer)
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
    private var labs: some View {
        if #available(iOS 17.0, *) {
            Section {
                Toggle(isOn: $viewModel.configuration.enableOnDeviceSTT) {
                    toggleLabel(symbol: .micFill, text: L10n.Assist.Settings.OnDeviceStt.title)
                }

                if viewModel.configuration.enableOnDeviceSTT, !viewModel.supportedSTTLocales.isEmpty {
                    Picker(L10n.Assist.Settings.OnDeviceStt.language, selection: onDeviceSTTLocaleBinding) {
                        ForEach(viewModel.supportedSTTLocales, id: \.identifier) { locale in
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
                            Text(viewModel.selectedVoiceDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(L10n.Assist.Settings.Section.Labs.title)
                    LabsLabel()
                }
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
