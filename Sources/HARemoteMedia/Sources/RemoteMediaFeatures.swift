import Foundation

/// The `supported_features` bits of a `media_player` that Remote Now Playing acts on, with Home
/// Assistant Core's `MediaPlayerEntityFeature` values. Other bits are dropped, so a snapshot carries
/// `supported_features & 20535`, or none when the value is negative (which would otherwise claim
/// every bit).
public struct RemoteMediaFeatures: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let pause = Self(rawValue: 1)
    public static let seek = Self(rawValue: 2)
    public static let volumeSet = Self(rawValue: 4)
    public static let previousTrack = Self(rawValue: 16)
    public static let nextTrack = Self(rawValue: 32)
    public static let stop = Self(rawValue: 4096)
    public static let play = Self(rawValue: 16384)

    static let understood: Self = [.pause, .seek, .volumeSet, .previousTrack, .nextTrack, .stop, .play]

    init(supportedFeatures: Int) {
        self = supportedFeatures < 0 ? [] : Self(rawValue: supportedFeatures).intersection(.understood)
    }
}
