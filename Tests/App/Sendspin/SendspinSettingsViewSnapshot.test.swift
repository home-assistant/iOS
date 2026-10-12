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
        nowPlaying: SendspinMetadataState? = nil
    ) -> some View {
        NavigationView {
            SendspinSettingsView(viewModel: SendspinSettingsViewModel(
                configuration: configuration,
                controller: nil,
                status: status,
                pairedServers: pairedServers,
                nowPlaying: nowPlaying,
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
            of: screen(.init(isEnabled: true), status: .listening(port: 8928)),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func playing() {
        assertLightDarkSnapshots(
            of: screen(
                .init(isEnabled: true, playerName: "Kitchen", outputDelayMs: 40),
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
                    progress: nil
                )
            ),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func failed() {
        assertLightDarkSnapshots(
            of: screen(.init(isEnabled: true), status: .failed(message: "Address already in use")),
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
