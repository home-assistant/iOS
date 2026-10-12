import Foundation
import Shared
import SwiftUI

struct SendspinSettingsView: View {
    @StateObject private var viewModel: SendspinSettingsViewModel
    @State private var playerName = ""
    @State private var isConfirmingForget = false

    init() {
        let controller = SendspinPlayerController.shared
        self.init(viewModel: SendspinSettingsViewModel(
            configuration: controller.configuration,
            controller: controller,
            pairingToken: controller.pairingToken.string,
            defaultPlayerName: WyomingServiceCatalog.advertisedDeviceName()
        ))
    }

    /// Injectable so previews and snapshot tests can show a connected or failed player without one
    /// actually running on the device rendering them.
    init(viewModel: @autoclosure @escaping () -> SendspinSettingsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .speakerWirelessIcon,
                title: L10n.Settings.Sendspin.title,
                subtitle: L10n.Settings.Sendspin.body
            )

            Section {
                Toggle(L10n.Settings.Sendspin.toggle, isOn: $viewModel.configuration.isEnabled)
            } footer: {
                Text(L10n.Settings.Sendspin.footer)
            }

            if viewModel.configuration.isEnabled {
                Section {
                    HStack {
                        Text(L10n.Settings.Sendspin.Player.status)
                        Spacer()
                        Text(viewModel.statusDescription)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    if let nowPlaying = viewModel.nowPlayingDescription {
                        HStack {
                            Text(L10n.Settings.Sendspin.nowPlaying)
                            Spacer()
                            Text(nowPlaying)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                        }
                    }
                    HStack {
                        Text(L10n.Settings.Sendspin.Player.name)
                        Spacer()
                        TextField(viewModel.defaultPlayerName, text: $playerName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .submitLabel(.done)
                            .onSubmit {
                                viewModel.commitPlayerName(playerName)
                            }
                    }
                } footer: {
                    Text(L10n.Settings.Sendspin.Player.footer)
                }

                Section {
                    Stepper(
                        value: $viewModel.configuration.outputDelayMs,
                        in: 0 ... SendspinPlayerConfiguration.maximumOutputDelayMs,
                        step: 10
                    ) {
                        HStack {
                            Text(L10n.Settings.Sendspin.OutputDelay.title)
                            Spacer()
                            Text(L10n.Settings.Sendspin.OutputDelay.value(viewModel.configuration.outputDelayMs))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    Text(L10n.Settings.Sendspin.OutputDelay.footer)
                }

                Section {
                    Toggle(L10n.Settings.Sendspin.unpairedAccess, isOn: $viewModel.configuration.allowsUnpairedAccess)
                    NavigationLink {
                        SendspinPairingTokenView(token: viewModel.pairingToken)
                    } label: {
                        Text(L10n.Settings.Sendspin.PairingToken.title)
                    }
                } header: {
                    Text(L10n.Settings.Sendspin.Security.header)
                } footer: {
                    Text(L10n.Settings.Sendspin.Security.footer)
                }

                if !viewModel.pairedServers.isEmpty {
                    Section {
                        ForEach(viewModel.pairedServers) { server in
                            Text(server.serverName)
                        }
                        Button(L10n.Settings.Sendspin.ForgetPairedServers.title, role: .destructive) {
                            isConfirmingForget = true
                        }
                        .confirmationDialog(
                            L10n.Settings.Sendspin.ForgetPairedServers.title,
                            isPresented: $isConfirmingForget,
                            titleVisibility: .visible
                        ) {
                            Button(L10n.Settings.Sendspin.ForgetPairedServers.confirm, role: .destructive) {
                                viewModel.forgetPairedServers()
                            }
                        } message: {
                            Text(L10n.Settings.Sendspin.ForgetPairedServers.message)
                        }
                    } header: {
                        Text(L10n.Settings.Sendspin.PairedServers.header)
                    }
                }
            }

            Section {
                NavigationLink {
                    SendspinConnectInstructionsView()
                } label: {
                    Text(L10n.Settings.Sendspin.Connect.title)
                }
            }
        }
        .onAppear {
            playerName = viewModel.configuration.playerName ?? ""
        }
    }
}

extension SendspinSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.Sendspin.toggle),
            SettingsSearchEntry(L10n.Settings.Sendspin.Player.name),
            SettingsSearchEntry(L10n.Settings.Sendspin.OutputDelay.title),
            SettingsSearchEntry(L10n.Settings.Sendspin.unpairedAccess),
            SettingsSearchEntry(L10n.Settings.Sendspin.PairingToken.title),
            SettingsSearchEntry(L10n.Settings.Sendspin.Connect.title),
        ]
    }
}

#Preview("Playing") {
    NavigationView {
        SendspinSettingsView(viewModel: SendspinSettingsViewModel(
            configuration: .init(isEnabled: true, outputDelayMs: 40),
            controller: nil,
            status: .playing(serverName: "Music Assistant"),
            pairedServers: [
                SendspinPairingRecord(serverID: "server", serverName: "Music Assistant", psk: "", lastUsed: Date()),
            ],
            nowPlaying: SendspinMetadataState(
                timestamp: 0,
                title: "Clair de Lune",
                artist: "Claude Debussy",
                albumArtist: nil,
                album: nil,
                artworkURL: nil,
                year: nil,
                track: nil,
                progress: nil
            ),
            pairingToken: "SP:0AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYP6BYPC4PSOLZXH5DU6V97M5XXO74HR6LZ7J5PW674PT6X37T6757Y",
            defaultPlayerName: "iPhone"
        ))
    }
}

#Preview("Off") {
    NavigationView {
        SendspinSettingsView(viewModel: SendspinSettingsViewModel(
            configuration: .init(),
            controller: nil,
            pairingToken: "",
            defaultPlayerName: "iPhone"
        ))
    }
}
