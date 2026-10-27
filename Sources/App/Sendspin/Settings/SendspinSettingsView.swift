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
            servers: Current.servers.all.map(SendspinServerOption.init(server:)),
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
                ForEach(viewModel.servers) { server in
                    Toggle(isOn: Binding(
                        get: { viewModel.isEnabled(for: server) },
                        set: { viewModel.setEnabled($0, for: server) }
                    )) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(server.name)
                            if !server.hasHomeNetwork {
                                Text(L10n.Settings.Sendspin.Servers.noHomeNetwork)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(L10n.Settings.Sendspin.Servers.header)
            } footer: {
                Text(L10n.Settings.Sendspin.Servers.footer)
            }

            if viewModel.isEnabledForAnyServer {
                Section {
                    Text(viewModel.statusDescription)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text(L10n.Settings.Sendspin.Player.status)
                }

                if let title = viewModel.nowPlayingTitle {
                    Section {
                        AsyncImage(url: viewModel.artworkURL) { phase in
                            HAMediaControlCard(
                                name: viewModel.playerDisplayName,
                                title: title,
                                subtitle: viewModel.nowPlayingSubtitle,
                                artwork: phase.image,
                                isPlaying: viewModel.isPlaying,
                                onPlayPause: viewModel.canPlayOrPause ? { viewModel.playOrPause() } : nil,
                                onPrevious: viewModel.supports("previous") ? { viewModel.previous() } : nil,
                                onNext: viewModel.supports("next") ? { viewModel.next() } : nil
                            )
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(L10n.Settings.Sendspin.nowPlaying)
                    }

                    if viewModel.supports("volume") || viewModel.supports("mute") {
                        Section {
                            HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                                Button {
                                    viewModel.toggleMute()
                                } label: {
                                    Image(systemSymbol: viewModel.isMuted ? .speakerSlashFill : .speakerFill)
                                }
                                .buttonStyle(.borderless)
                                .disabled(!viewModel.supports("mute"))
                                .accessibilityLabel(
                                    viewModel.isMuted
                                        ? L10n.Component.MediaControl.unmute
                                        : L10n.Component.MediaControl.mute
                                )
                                Slider(
                                    value: $viewModel.groupVolume,
                                    in: 0 ... 100,
                                    onEditingChanged: { viewModel.setEditingGroupVolume($0) }
                                )
                                .disabled(!viewModel.supports("volume"))
                                .accessibilityLabel(L10n.Component.MediaControl.volume)
                                Image(systemSymbol: .speakerWave3Fill)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }

                Section {
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
            SettingsSearchEntry(L10n.Settings.Sendspin.Servers.header),
            SettingsSearchEntry(L10n.Settings.Sendspin.Player.name),
            SettingsSearchEntry(L10n.Settings.Sendspin.unpairedAccess),
            SettingsSearchEntry(L10n.Settings.Sendspin.PairingToken.title),
            SettingsSearchEntry(L10n.Settings.Sendspin.Connect.title),
        ]
    }
}

#Preview("Playing") {
    NavigationView {
        SendspinSettingsView(viewModel: SendspinSettingsViewModel(
            configuration: .init(enabledServerIdentifiers: ["home"]),
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
            controllerState: SendspinControllerState(
                supportedCommands: ["play", "pause", "next", "previous", "volume", "mute"],
                volume: 40,
                muted: false,
                repeat: "off",
                shuffle: false,
                seekMaxMs: nil
            ),
            servers: [
                SendspinServerOption(id: "home", name: "Home", hasHomeNetwork: true),
                SendspinServerOption(id: "cabin", name: "Cabin", hasHomeNetwork: false),
            ],
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
            servers: [SendspinServerOption(id: "home", name: "Home", hasHomeNetwork: true)],
            pairingToken: "",
            defaultPlayerName: "iPhone"
        ))
    }
}
