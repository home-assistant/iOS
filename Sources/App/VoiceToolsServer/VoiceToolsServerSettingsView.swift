import Foundation
import Shared
import SwiftUI

struct VoiceToolsServerSettingsView: View {
    @StateObject private var viewModel: VoiceToolsServerSettingsViewModel
    @State private var portText = ""

    init() {
        self.init(viewModel: VoiceToolsServerSettingsViewModel(
            configuration: VoiceToolsServerConfiguration.config,
            controller: WyomingServerController.shared,
            isSpeechRecognitionAuthorized: WyomingServerController.isSpeechRecognitionAuthorized
        ))
    }

    /// Injectable so previews and snapshot tests can show a running or failed listener without one
    /// actually being bound on the device rendering them.
    init(viewModel: @autoclosure @escaping () -> VoiceToolsServerSettingsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    private var statusDescription: String {
        switch viewModel.state {
        case .stopped:
            return L10n.Settings.VoiceToolsServer.Status.stopped
        case .starting:
            return L10n.Settings.VoiceToolsServer.Status.starting
        case let .running(port):
            return L10n.Settings.VoiceToolsServer.Status.running(String(port))
        case let .failed(message):
            return message
        }
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .accountVoiceIcon,
                title: L10n.Settings.VoiceToolsServer.title,
                subtitle: L10n.Settings.VoiceToolsServer.body
            )

            Section {
                Toggle(L10n.Settings.VoiceToolsServer.toggle, isOn: $viewModel.configuration.isEnabled)
            } footer: {
                Text(L10n.Settings.VoiceToolsServer.footer)
            }

            if viewModel.configuration.isEnabled {
                Section {
                    HStack {
                        Text(L10n.Settings.VoiceToolsServer.statusTitle)
                        Spacer()
                        Text(statusDescription)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.Settings.VoiceToolsServer.port)
                        Spacer()
                        TextField(L10n.Settings.VoiceToolsServer.port, text: $portText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(L10n.Settings.VoiceToolsServer.enabledFooter)
                }

                if !viewModel.isSpeechRecognitionAuthorized {
                    Section {
                        Label(
                            L10n.Settings.VoiceToolsServer.speechPermission,
                            systemSymbol: .exclamationmarkTriangleFill
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                NavigationLink {
                    VoiceToolsServerLanguagesView()
                } label: {
                    Text(L10n.Settings.VoiceToolsServer.Languages.title)
                }
                NavigationLink {
                    VoiceToolsServerVoicesView()
                } label: {
                    Text(L10n.Settings.VoiceToolsServer.Voices.title)
                }
            } header: {
                Text(L10n.Settings.VoiceToolsServer.OnDevice.header)
            } footer: {
                Text(L10n.Settings.VoiceToolsServer.OnDevice.footer)
            }
        }
        .onAppear {
            portText = String(viewModel.configuration.port)
        }
        .onChange(of: portText) { newValue in
            // Only a port the system can actually bind is stored; anything else leaves the last
            // good value in place so half-typed input does not tear the listener down.
            guard let port = Int(newValue), (1 ... 65535).contains(port) else { return }
            viewModel.configuration.port = port
        }
        .onChange(of: viewModel.configuration.isEnabled) { isEnabled in
            guard isEnabled else { return }
            Task {
                await viewModel.requestSpeechRecognitionAuthorization()
            }
        }
    }
}

extension VoiceToolsServerSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.VoiceToolsServer.toggle),
            SettingsSearchEntry(L10n.Settings.VoiceToolsServer.statusTitle),
            SettingsSearchEntry(L10n.Settings.VoiceToolsServer.port),
            SettingsSearchEntry(L10n.Settings.VoiceToolsServer.Languages.title),
            SettingsSearchEntry(L10n.Settings.VoiceToolsServer.Voices.title),
        ]
    }
}

#Preview("Running") {
    NavigationView {
        VoiceToolsServerSettingsView(viewModel: VoiceToolsServerSettingsViewModel(
            configuration: .init(isEnabled: true),
            controller: nil,
            state: .running(port: 10700)
        ))
    }
}

#Preview("Off") {
    NavigationView {
        VoiceToolsServerSettingsView(viewModel: VoiceToolsServerSettingsViewModel(
            configuration: .init(),
            controller: nil
        ))
    }
}
