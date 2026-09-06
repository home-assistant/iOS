import Foundation
import MediaPlayer
import Shared

/// Publishes the group's track to the lock screen and Control Centre, and turns the transport
/// buttons there into `controller` commands for the group.
///
/// The device is a speaker in someone else's group, so the remote commands do not control local
/// playback: pausing here pauses the group on the server, which is what the user means when they
/// pause the thing they can hear.
@MainActor
final class SendspinNowPlayingController {
    /// Invoked with the command the user pressed, for the manager to forward to the server.
    var onCommand: ((SendspinControllerCommand) -> Void)?

    private var isRegistered = false

    func update(
        metadata: SendspinTrackMetadata?,
        positionMilliseconds: Int?,
        isPlaying: Bool,
        controller: SendspinControllerState?
    ) {
        guard let metadata else {
            clear()
            return
        }

        register(supporting: controller)

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = metadata.title ?? ""
        info[MPMediaItemPropertyArtist] = metadata.artist
        info[MPMediaItemPropertyAlbumTitle] = metadata.album
        info[MPMediaItemPropertyAlbumArtist] = metadata.albumArtist
        if let duration = metadata.progress?.trackDuration, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(duration) / 1_000
        }
        if let positionMilliseconds {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(positionMilliseconds) / 1_000
        }
        let speed = metadata.progress?.playbackSpeed ?? (isPlaying ? 1_000 : 0)
        info[MPNowPlayingInfoPropertyPlaybackRate] = Double(speed) / 1_000
        info[MPNowPlayingInfoPropertyIsLiveStream] = (metadata.progress?.trackDuration ?? 0) == 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    /// Only offers the buttons the group says it supports, so a control never silently does nothing.
    private func register(supporting controller: SendspinControllerState?) {
        let center = MPRemoteCommandCenter.shared()
        if !isRegistered {
            isRegistered = true
            center.playCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.onCommand?(.play) }
                return .success
            }
            center.pauseCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.onCommand?(.pause) }
                return .success
            }
            center.nextTrackCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.onCommand?(.next) }
                return .success
            }
            center.previousTrackCommand.addTarget { [weak self] _ in
                Task { @MainActor in self?.onCommand?(.previous) }
                return .success
            }
            center.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                let position = Int(event.positionTime * 1_000)
                Task { @MainActor in self?.onCommand?(.seek(positionMs: position)) }
                return .success
            }
        }

        center.playCommand.isEnabled = controller?.supports("play") ?? false
        center.pauseCommand.isEnabled = controller?.supports("pause") ?? false
        center.nextTrackCommand.isEnabled = controller?.supports("next") ?? false
        center.previousTrackCommand.isEnabled = controller?.supports("previous") ?? false
        center.changePlaybackPositionCommand.isEnabled = controller?.supports("seek") ?? false
    }
}
