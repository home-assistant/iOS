import Foundation

/// Home Assistant Core's MediaPlayerEntityFeature values:
/// https://github.com/home-assistant/core/blob/dev/homeassistant/components/media_player/const.py
public struct RemoteMediaFeatures: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let pause = Self(rawValue: 1)
    public static let seek = Self(rawValue: 2)
    public static let volumeSet = Self(rawValue: 4)
    public static let volumeMute = Self(rawValue: 8)
    public static let previous = Self(rawValue: 16)
    public static let next = Self(rawValue: 32)
    public static let stop = Self(rawValue: 4096)
    public static let play = Self(rawValue: 16384)

    public var commands: Set<RemoteMediaCommand> {
        var result = Set<RemoteMediaCommand>()
        for (feature, command): (Self, RemoteMediaCommand) in [
            (.play, .play), (.pause, .pause), (.stop, .stop),
            (.previous, .previous), (.next, .next), (.seek, .seek), (.volumeSet, .volume),
        ] where contains(feature) {
            result.insert(command)
        }
        if contains([.play, .pause]) { result.insert(.togglePlayPause) }
        return result
    }
}
