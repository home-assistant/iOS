import Foundation
import MediaPlayer
import Shared
import UIKit

/// Shows what Music Assistant is playing on the lock screen and in Control Center, and turns the
/// transport controls there into group commands.
@MainActor
final class SendspinNowPlaying {
    private let onCommand: (SendspinControllerCommand) -> Void
    private var registeredTargets: [(MPRemoteCommand, Any)] = []
    private var artworkURL: String?
    private var artwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    private var info: [String: Any] = [:]

    init(onCommand: @escaping (SendspinControllerCommand) -> Void) {
        self.onCommand = onCommand
    }

    func update(metadata: SendspinMetadataState?, positionMs: Int64?) {
        guard let metadata else {
            clear()
            return
        }
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = metadata.title
        info[MPMediaItemPropertyArtist] = metadata.artist
        info[MPMediaItemPropertyAlbumTitle] = metadata.album
        info[MPMediaItemPropertyAlbumArtist] = metadata.albumArtist
        if let progress = metadata.progress {
            if progress.trackDuration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = Double(progress.trackDuration) / 1000
            }
            info[MPNowPlayingInfoPropertyPlaybackRate] = Double(progress.playbackSpeed) / 1000
        }
        if let positionMs {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(positionMs) / 1000
        }
        if metadata.artworkURL != artworkURL {
            artworkURL = metadata.artworkURL
            artwork = nil
            loadArtwork(from: metadata.artworkURL)
        }
        info[MPMediaItemPropertyArtwork] = artwork
        self.info = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Enables exactly the transport controls the group currently accepts.
    func update(controller: SendspinControllerState?) {
        unregisterCommands()
        guard let controller else { return }
        let center = MPRemoteCommandCenter.shared()
        let supported = Set(controller.supportedCommands)
        register(center.playCommand, command: "play", supported: supported)
        register(center.pauseCommand, command: "pause", supported: supported)
        register(center.stopCommand, command: "stop", supported: supported)
        register(center.nextTrackCommand, command: "next", supported: supported)
        register(center.previousTrackCommand, command: "previous", supported: supported)
        center.togglePlayPauseCommand.isEnabled = supported.contains("play") || supported.contains("pause")
        let toggle = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            let isPlaying = (info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0) > 0
            onCommand(SendspinControllerCommand(command: isPlaying ? "pause" : "play"))
            return .success
        }
        registeredTargets.append((center.togglePlayPauseCommand, toggle))
    }

    func clear() {
        artworkTask?.cancel()
        artworkURL = nil
        artwork = nil
        info = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func register(_ remoteCommand: MPRemoteCommand, command: String, supported: Set<String>) {
        remoteCommand.isEnabled = supported.contains(command)
        let target = remoteCommand.addTarget { [weak self] _ in
            self?.onCommand(SendspinControllerCommand(command: command))
            return .success
        }
        registeredTargets.append((remoteCommand, target))
    }

    private func unregisterCommands() {
        for (command, target) in registeredTargets {
            command.removeTarget(target)
            command.isEnabled = false
        }
        registeredTargets.removeAll()
    }

    private func loadArtwork(from urlString: String?) {
        artworkTask?.cancel()
        guard let urlString, let url = URL(string: urlString) else { return }
        artworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data), !Task.isCancelled else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self?.artwork = artwork
            self?.info[MPMediaItemPropertyArtwork] = artwork
            if let info = self?.info {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
}
