import Foundation
@testable import HomeAssistant
import Shared
import Testing

@MainActor
struct SendspinSettingsViewModelTests {
    private func makeViewModel(
        status: SendspinPlayerStatus = .stopped,
        nowPlaying: SendspinMetadataState? = nil
    ) -> SendspinSettingsViewModel {
        SendspinSettingsViewModel(
            configuration: .init(isEnabled: true),
            controller: nil,
            status: status,
            pairedServers: [SendspinPairingRecord(serverID: "a", serverName: "A", psk: "", lastUsed: Date())],
            nowPlaying: nowPlaying,
            pairingToken: "SP:0TOKEN",
            defaultPlayerName: "iPhone"
        )
    }

    private func metadata(title: String?, artist: String?) -> SendspinMetadataState {
        SendspinMetadataState(
            timestamp: 0,
            title: title,
            artist: artist,
            albumArtist: nil,
            album: nil,
            artworkURL: nil,
            year: nil,
            track: nil,
            progress: nil
        )
    }

    @Test(arguments: [
        (SendspinPlayerStatus.stopped, L10n.Settings.Sendspin.Status.stopped),
        (.starting, L10n.Settings.Sendspin.Status.starting),
        (.listening(port: 8928), L10n.Settings.Sendspin.Status.listening),
        (.connected(serverName: "MA"), L10n.Settings.Sendspin.Status.connected("MA")),
        (.playing(serverName: "MA"), L10n.Settings.Sendspin.Status.playing("MA")),
        (.failed(message: "Address in use"), "Address in use"),
    ])
    func describesEveryStatus(status: SendspinPlayerStatus, description: String) {
        #expect(makeViewModel(status: status).statusDescription == description)
    }

    @Test func describesWhatIsPlaying() {
        #expect(makeViewModel().nowPlayingDescription == nil)
        #expect(makeViewModel(nowPlaying: metadata(title: "", artist: "B")).nowPlayingDescription == nil)
        #expect(makeViewModel(nowPlaying: metadata(title: "Song", artist: nil)).nowPlayingDescription == "Song")
        #expect(
            makeViewModel(nowPlaying: metadata(title: "Song", artist: "Band"))
                .nowPlayingDescription == "Song – Band"
        )
    }

    @Test func committingAnEmptyNameFollowsTheDevice() {
        let viewModel = makeViewModel()
        viewModel.commitPlayerName("  Kitchen  ")
        #expect(viewModel.configuration.playerName == "Kitchen")
        viewModel.commitPlayerName("   ")
        #expect(viewModel.configuration.playerName == nil)
    }

    @Test func forgettingClearsTheList() {
        let viewModel = makeViewModel()
        viewModel.forgetPairedServers()
        #expect(viewModel.pairedServers.isEmpty)
    }

    /// The live path: the screen mirrors the controller and hands it every change.
    @Test func followsAndUpdatesTheController() async throws {
        let controller = SendspinPlayerController(
            credentials: SendspinMemoryCredentialStore(),
            configuration: SendspinPlayerConfiguration()
        )
        let viewModel = SendspinSettingsViewModel(
            configuration: .init(),
            controller: controller,
            pairingToken: controller.pairingToken.string,
            defaultPlayerName: "iPhone"
        )
        #expect(viewModel.status == .stopped)
        #expect(viewModel.pairingToken.hasPrefix("SP:0"))
        #expect(
            SendspinPairingToken(string: viewModel.pairingToken)?.clientKey
                == controller.credentials.identity().publicKeyBytes
        )
        viewModel.forgetPairedServers()
        #expect(controller.pairedServers.isEmpty)
    }
}
