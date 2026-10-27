import Foundation
@testable import HomeAssistant
import Shared
import Testing

@MainActor
struct SendspinSettingsViewModelTests {
    private func makeViewModel(
        configuration: SendspinPlayerConfiguration = .init(enabledServerIdentifiers: ["home"]),
        status: SendspinPlayerStatus = .stopped,
        nowPlaying: SendspinMetadataState? = nil,
        controllerState: SendspinControllerState? = nil
    ) -> SendspinSettingsViewModel {
        SendspinSettingsViewModel(
            configuration: configuration,
            controller: nil,
            status: status,
            pairedServers: [SendspinPairingRecord(serverID: "a", serverName: "A", psk: "", lastUsed: Date())],
            nowPlaying: nowPlaying,
            controllerState: controllerState,
            servers: [
                SendspinServerOption(id: "home", name: "Home", hasHomeNetwork: true),
                SendspinServerOption(id: "cabin", name: "Cabin", hasHomeNetwork: false),
            ],
            pairingToken: "SP:0TOKEN",
            defaultPlayerName: "iPhone"
        )
    }

    private func metadata(
        title: String?,
        artist: String?,
        album: String? = nil,
        playbackSpeed: Int? = nil
    ) -> SendspinMetadataState {
        SendspinMetadataState(
            timestamp: 0,
            title: title,
            artist: artist,
            albumArtist: nil,
            album: album,
            artworkURL: nil,
            year: nil,
            track: nil,
            progress: playbackSpeed.map {
                SendspinTrackProgress(trackProgress: 0, trackDuration: 1000, playbackSpeed: $0)
            }
        )
    }

    private func controllerState(
        _ supportedCommands: [String],
        volume: Int = 40,
        muted: Bool = false
    ) -> SendspinControllerState {
        SendspinControllerState(
            supportedCommands: supportedCommands,
            volume: volume,
            muted: muted,
            repeat: "off",
            shuffle: false,
            seekMaxMs: nil
        )
    }

    @Test(arguments: [
        (SendspinPlayerStatus.stopped, L10n.Settings.Sendspin.Status.stopped),
        (.awayFromHomeNetwork, L10n.Settings.Sendspin.Status.awayFromHomeNetwork),
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
        #expect(makeViewModel().nowPlayingTitle == nil)
        #expect(makeViewModel(nowPlaying: metadata(title: "", artist: "B")).nowPlayingTitle == nil)
        let song = makeViewModel(nowPlaying: metadata(title: "Song", artist: nil))
        #expect(song.nowPlayingTitle == "Song")
        #expect(song.nowPlayingSubtitle == nil)
        #expect(
            makeViewModel(nowPlaying: metadata(title: "Song", artist: "Band", album: "Album"))
                .nowPlayingSubtitle == "Band · Album"
        )
    }

    @Test func turnsOnPerServer() {
        let viewModel = makeViewModel(configuration: .init())
        let home = viewModel.servers[0]
        let cabin = viewModel.servers[1]
        #expect(!viewModel.isEnabledForAnyServer)
        viewModel.setEnabled(true, for: cabin)
        #expect(viewModel.isEnabled(for: cabin))
        #expect(!viewModel.isEnabled(for: home))
        #expect(viewModel.isEnabledForAnyServer)
        #expect(viewModel.configuration.enabledServerIdentifiers == ["cabin"])
    }

    @Test func ignoresServersThatNoLongerExist() {
        #expect(!makeViewModel(configuration: .init(enabledServerIdentifiers: ["removed"])).isEnabledForAnyServer)
    }

    @Test func offersOnlyTheCommandsTheGroupSupports() {
        let viewModel = makeViewModel(
            nowPlaying: metadata(title: "Song", artist: nil, playbackSpeed: 1000),
            controllerState: controllerState(["pause", "next"])
        )
        #expect(viewModel.isPlaying)
        #expect(viewModel.canPlayOrPause)
        #expect(viewModel.supports("next"))
        #expect(!viewModel.supports("previous"))
        #expect(!viewModel.supports("volume"))
        #expect(!makeViewModel().supports("play"))
    }

    @Test func pausedTrackOffersPlay() {
        let viewModel = makeViewModel(
            nowPlaying: metadata(title: "Song", artist: nil, playbackSpeed: 0),
            controllerState: controllerState(["pause"])
        )
        #expect(!viewModel.isPlaying)
        #expect(!viewModel.canPlayOrPause)
    }

    @Test func groupVolumeFollowsTheServerExceptWhileDragging() {
        let viewModel = makeViewModel(controllerState: controllerState(["volume", "mute"], volume: 40, muted: true))
        #expect(viewModel.groupVolume == 40)
        #expect(viewModel.isMuted)
        viewModel.setEditingGroupVolume(true)
        viewModel.groupVolume = 70
        viewModel.setEditingGroupVolume(false)
        #expect(viewModel.groupVolume == 70)
    }

    @Test func sendingControlsWithoutAPlayerChangesNothing() {
        let viewModel = makeViewModel(controllerState: controllerState(["play", "next", "previous", "mute"]))
        viewModel.playOrPause()
        viewModel.previous()
        viewModel.next()
        viewModel.toggleMute()
        #expect(viewModel.controllerState == controllerState(["play", "next", "previous", "mute"]))
    }

    @Test func showsTheTypedNameOrTheDevice() {
        #expect(makeViewModel().playerDisplayName == "iPhone")
        #expect(makeViewModel(configuration: .init(playerName: "Kitchen")).playerDisplayName == "Kitchen")
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
