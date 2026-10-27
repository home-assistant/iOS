@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

struct SendspinSettingsViewSnapshotTests {
    private static let token =
        "SP:0AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYP6BYPC4PSOLZXH5DU6V97M5XXO74HR6LZ7J5PW674PT6X37T6757Y"

    /// The controller is left out of every case: these must render the same wherever they run,
    /// without opening a port on the machine running them.
    @MainActor private func screen(
        _ configuration: SendspinPlayerConfiguration,
        status: SendspinPlayerStatus = .stopped,
        pairedServers: [SendspinPairingRecord] = [],
        nowPlaying: SendspinMetadataState? = nil,
        controllerState: SendspinControllerState? = nil
    ) -> some View {
        NavigationView {
            SendspinSettingsView(viewModel: SendspinSettingsViewModel(
                configuration: configuration,
                controller: nil,
                status: status,
                pairedServers: pairedServers,
                nowPlaying: nowPlaying,
                controllerState: controllerState,
                servers: [
                    SendspinServerOption(id: "home", name: "Home", hasHomeNetwork: true),
                    SendspinServerOption(id: "cabin", name: "Cabin", hasHomeNetwork: false),
                ],
                pairingToken: Self.token,
                defaultPlayerName: "iPhone"
            ))
        }
    }

    @MainActor @Test func off() {
        assertLightDarkSnapshots(of: screen(.init()), drawHierarchyInKeyWindow: true)
    }

    @MainActor @Test func waitingForMusicAssistant() {
        assertLightDarkSnapshots(
            of: screen(.init(enabledServerIdentifiers: ["home"]), status: .listening(port: 8928)),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func playing() {
        assertLightDarkSnapshots(
            of: screen(
                .init(enabledServerIdentifiers: ["home"], playerName: "Kitchen"),
                status: .playing(serverName: "Music Assistant"),
                pairedServers: [
                    SendspinPairingRecord(serverID: "a", serverName: "Music Assistant", psk: "", lastUsed: Date()),
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
                    progress: SendspinTrackProgress(trackProgress: 0, trackDuration: 300_000, playbackSpeed: 1000)
                ),
                controllerState: SendspinControllerState(
                    supportedCommands: ["pause", "next", "previous", "volume", "mute"],
                    volume: 40,
                    muted: false,
                    repeat: "off",
                    shuffle: false,
                    seekMaxMs: nil
                )
            ),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func failed() {
        assertLightDarkSnapshots(
            of: screen(
                .init(enabledServerIdentifiers: ["home"]),
                status: .failed(message: "Address already in use: the port Music Assistant connects to is taken")
            ),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func pairingToken() {
        assertLightDarkSnapshots(
            of: NavigationView { SendspinPairingTokenView(token: Self.token) },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func connectInstructions() {
        assertLightDarkSnapshots(
            of: NavigationView { SendspinConnectInstructionsView() },
            drawHierarchyInKeyWindow: true
        )
    }
}
