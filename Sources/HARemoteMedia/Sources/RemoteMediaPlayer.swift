import Foundation

/// The followed player as of its latest report: its name, what it is doing and what it can be asked to
/// do. It describes the device rather than the media, so it always follows the newest report.
///
/// Built only by `RemoteMediaSnapshotMapper`, which normalizes every value: an empty `deviceClass` is
/// none, `volume` is clamped to `0...1`, and `features` keeps only the bits `RemoteMediaFeatures`
/// understands.
public struct RemoteMediaPlayer: Equatable, Sendable {
    /// The entity's `friendly_name`, or its entity id when that is missing or empty. Never empty.
    public let name: String
    /// The entity's `device_class` verbatim, such as `tv` or `speaker`.
    public let deviceClass: String?
    public let playback: RemoteMediaPlaybackState
    /// `volume_level`, from 0 to 1.
    public let volume: Double?
    public let features: RemoteMediaFeatures

    /// `name` must not be empty: the mapper falls back to the entity id, and decoding refuses it.
    init(
        name: String,
        deviceClass: String?,
        playback: RemoteMediaPlaybackState,
        volume: Double?,
        features: RemoteMediaFeatures
    ) {
        self.name = name
        self.deviceClass = deviceClass.flatMap { $0.isEmpty ? nil : $0 }
        self.playback = playback
        self.volume = volume.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
        self.features = RemoteMediaFeatures(supportedFeatures: features.rawValue)
    }

    func with(playback: RemoteMediaPlaybackState) -> Self {
        Self(name: name, deviceClass: deviceClass, playback: playback, volume: volume, features: features)
    }
}
