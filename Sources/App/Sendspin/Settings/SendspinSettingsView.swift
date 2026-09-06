import SFSafeSymbols
import Shared
import SwiftUI

struct SendspinSettingsView: View {
    @ObservedObject private var manager = SendspinPlayerManager.shared
    @State private var playerName = SendspinPreferences.playerName
    @State private var unpairedAccessEnabled = SendspinPreferences.unpairedAccessEnabled
    @State private var isConfirmingForget = false

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .speakerMultipleIcon,
                title: L10n.Settings.Sendspin.title,
                subtitle: L10n.Settings.Sendspin.Header.subtitle
            )

            Section(footer: Text(L10n.Settings.Sendspin.Enable.footer)) {
                Toggle(isOn: Binding(
                    get: { manager.isEnabled },
                    set: { manager.setEnabled($0) }
                )) {
                    Text(L10n.Settings.Sendspin.Enable.title)
                }
                LabeledContent(L10n.Settings.Sendspin.Status.title) {
                    Text(statusDescription)
                        .foregroundStyle(.secondary)
                }
            }

            if manager.isEnabled {
                Section(
                    header: Text(L10n.Settings.Sendspin.Servers.header),
                    footer: Text(L10n.Settings.Sendspin.Servers.footer)
                ) {
                    if manager.servers.isEmpty {
                        Text(L10n.Settings.Sendspin.Servers.empty)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        manager.selectServer(nil)
                    } label: {
                        HStack {
                            Text(L10n.Settings.Sendspin.Servers.automatic)
                                .foregroundStyle(.primary)
                            Spacer()
                            if manager.selectedServerName == nil {
                                Image(systemSymbol: .checkmark)
                                    .foregroundStyle(.haPrimary)
                            }
                        }
                    }
                    ForEach(manager.servers) { server in
                        Button {
                            manager.selectServer(server)
                        } label: {
                            HStack {
                                Text(server.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if manager.selectedServerName == server.id {
                                    Image(systemSymbol: .checkmark)
                                        .foregroundStyle(.haPrimary)
                                }
                            }
                        }
                    }
                }

                Section(header: Text(L10n.Settings.Sendspin.NowPlaying.header)) {
                    if let metadata = manager.metadata {
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(metadata.title ?? L10n.Settings.Sendspin.NowPlaying.unknownTitle)
                                .font(.headline)
                            if let artist = metadata.artist {
                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let group = manager.group {
                                Text(group.groupName)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(L10n.Settings.Sendspin.NowPlaying.idle)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(
                    header: Text(L10n.Settings.Sendspin.Output.header),
                    footer: Text(L10n.Settings.Sendspin.Output.footer)
                ) {
                    Toggle(isOn: Binding(
                        get: { manager.isMuted },
                        set: { manager.setMuted($0) }
                    )) {
                        Text(L10n.Settings.Sendspin.Output.mute)
                    }
                    VStack(alignment: .leading) {
                        Text(L10n.Settings.Sendspin.Output.volume(manager.volume))
                        Slider(
                            value: Binding(
                                get: { Double(manager.volume) },
                                set: { manager.setVolume(Int($0.rounded())) }
                            ),
                            in: 0 ... 100,
                            step: 1
                        )
                    }
                    Stepper(
                        value: Binding(
                            get: { manager.outputDelayMilliseconds },
                            set: { manager.setOutputDelay(milliseconds: $0) }
                        ),
                        in: 0 ... 5_000,
                        step: 20
                    ) {
                        Text(L10n.Settings.Sendspin.Output.delay(manager.outputDelayMilliseconds))
                    }
                }

                Section(
                    header: Text(L10n.Settings.Sendspin.Pairing.header),
                    footer: Text(L10n.Settings.Sendspin.Pairing.footer)
                ) {
                    NavigationLink {
                        SendspinPairingView()
                    } label: {
                        Label {
                            Text(L10n.Settings.Sendspin.Pairing.row)
                        } icon: {
                            MaterialDesignIconsImage(icon: .qrcodeIcon, size: 20)
                        }
                    }
                    Toggle(isOn: Binding(
                        get: { unpairedAccessEnabled },
                        set: { newValue in
                            unpairedAccessEnabled = newValue
                            SendspinPreferences.unpairedAccessEnabled = newValue
                        }
                    )) {
                        Text(L10n.Settings.Sendspin.Pairing.allowUnpaired)
                    }
                    Text(L10n.Settings.Sendspin.Pairing.pairedCount(manager.pairedServerIds.count))
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        isConfirmingForget = true
                    } label: {
                        Text(L10n.Settings.Sendspin.Pairing.forget)
                    }
                    .confirmationDialog(
                        L10n.Settings.Sendspin.Pairing.forget,
                        isPresented: $isConfirmingForget,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.Settings.Sendspin.Pairing.forget, role: .destructive) {
                            manager.forgetPairings()
                        }
                        Button(L10n.cancelLabel, role: .cancel) {}
                    } message: {
                        Text(L10n.Settings.Sendspin.Pairing.forgetConfirmation)
                    }
                }

                Section(
                    header: Text(L10n.Settings.Sendspin.Name.header),
                    footer: Text(L10n.Settings.Sendspin.Name.footer)
                ) {
                    TextField(L10n.Settings.Sendspin.Name.header, text: $playerName)
                        .onSubmit {
                            SendspinPreferences.playerName = playerName
                        }
                }

                Section(header: Text(L10n.Settings.Sendspin.Diagnostics.header)) {
                    LabeledContent(
                        L10n.Settings.Sendspin.Diagnostics.stream,
                        value: manager.streamFormat.map(Self.describe) ?? "—"
                    )
                    LabeledContent(
                        L10n.Settings.Sendspin.Diagnostics.buffer,
                        value: "\(manager.statistics.bufferedMilliseconds) ms"
                    )
                    LabeledContent(
                        L10n.Settings.Sendspin.Diagnostics.dropouts,
                        value: "\(manager.statistics.underruns)"
                    )
                    LabeledContent(L10n.Settings.Sendspin.Diagnostics.deviceId, value: manager.clientId)
                        .textSelection(.enabled)
                }
            }
        }
        .listTopContentMargin()
    }

    private var statusDescription: String {
        switch manager.status {
        case .off:
            return L10n.Settings.Sendspin.Status.off
        case .searching:
            return L10n.Settings.Sendspin.Status.searching
        case let .connecting(serverName):
            return L10n.Settings.Sendspin.Status.connecting(serverName)
        case let .connected(serverName, trust, isReady):
            guard isReady else { return L10n.Settings.Sendspin.Status.synchronizing(serverName) }
            return trust == .paired
                ? L10n.Settings.Sendspin.Status.connectedPaired(serverName)
                : L10n.Settings.Sendspin.Status.connectedUnpaired(serverName)
        case let .failed(message):
            return message
        }
    }

    private static func describe(_ format: SendspinAudioFormat) -> String {
        "\(format.codec.rawValue.uppercased()) \(format.sampleRate / 1_000) kHz \(format.bitDepth)-bit"
    }
}

extension SendspinSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.Sendspin.Enable.title),
            SettingsSearchEntry(L10n.Settings.Sendspin.Pairing.row),
            SettingsSearchEntry(L10n.Settings.Sendspin.Output.header),
        ]
    }
}

#Preview {
    NavigationView {
        SendspinSettingsView()
    }
}
