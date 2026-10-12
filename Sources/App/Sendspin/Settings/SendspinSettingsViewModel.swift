import Combine
import Foundation
import Shared

@MainActor
final class SendspinSettingsViewModel: ObservableObject {
    @Published var configuration: SendspinPlayerConfiguration
    /// Mirrored from the controller so the screen shows the player's state live.
    @Published private(set) var status: SendspinPlayerStatus
    @Published private(set) var pairedServers: [SendspinPairingRecord]
    @Published private(set) var nowPlaying: SendspinMetadataState?
    let pairingToken: String
    let defaultPlayerName: String

    /// `nil` in previews and snapshot tests, which must show every state without opening a socket
    /// on the machine rendering them.
    private let controller: SendspinPlayerController?
    private var cancellables = Set<AnyCancellable>()

    /// None of the live values are defaulted here: default arguments are evaluated outside the main
    /// actor, and the controller lives on it. The screen's own initializer reads them.
    init(
        configuration: SendspinPlayerConfiguration,
        controller: SendspinPlayerController?,
        status: SendspinPlayerStatus = .stopped,
        pairedServers: [SendspinPairingRecord] = [],
        nowPlaying: SendspinMetadataState? = nil,
        pairingToken: String,
        defaultPlayerName: String
    ) {
        self.configuration = controller?.configuration ?? configuration
        self.controller = controller
        self.status = controller?.status ?? status
        self.pairedServers = controller?.pairedServers ?? pairedServers
        self.nowPlaying = controller?.nowPlaying ?? nowPlaying
        self.pairingToken = pairingToken
        self.defaultPlayerName = defaultPlayerName

        guard let controller else { return }
        // No `receive(on:)`: the controller is `@MainActor`, so these already arrive on the main
        // actor, and hopping again would leave the rows a run-loop turn behind.
        controller.$status.sink { [weak self] in self?.status = $0 }.store(in: &cancellables)
        controller.$pairedServers.sink { [weak self] in self?.pairedServers = $0 }.store(in: &cancellables)
        controller.$nowPlaying.sink { [weak self] in self?.nowPlaying = $0 }.store(in: &cancellables)
        // The server can change the volume or delay while the screen is open; the screen follows.
        controller.$configuration
            .sink { [weak self] configuration in
                guard let self, self.configuration != configuration else { return }
                self.configuration = configuration
            }
            .store(in: &cancellables)
        // The controller persists the settings and reconciles the player with them.
        $configuration
            .dropFirst()
            .sink { [weak controller] configuration in
                Task { @MainActor in controller?.update(configuration) }
            }
            .store(in: &cancellables)
    }

    var statusDescription: String {
        switch status {
        case .stopped:
            return L10n.Settings.Sendspin.Status.stopped
        case .starting:
            return L10n.Settings.Sendspin.Status.starting
        case .listening:
            return L10n.Settings.Sendspin.Status.listening
        case let .connected(serverName):
            return L10n.Settings.Sendspin.Status.connected(serverName)
        case let .playing(serverName):
            return L10n.Settings.Sendspin.Status.playing(serverName)
        case let .failed(message):
            return message
        }
    }

    var nowPlayingDescription: String? {
        guard let nowPlaying, let title = nowPlaying.title, !title.isEmpty else { return nil }
        guard let artist = nowPlaying.artist, !artist.isEmpty else { return title }
        return "\(title) – \(artist)"
    }

    /// Commits a typed name. An empty field goes back to following the device name.
    func commitPlayerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        configuration.playerName = trimmed.isEmpty ? nil : trimmed
    }

    func forgetPairedServers() {
        controller?.forgetPairedServers()
        pairedServers = []
    }
}
