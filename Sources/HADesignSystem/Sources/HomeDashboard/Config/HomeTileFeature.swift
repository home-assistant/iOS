import Foundation

/// The control a tile offers under its row. One per tile: the frontend picks the first that the
/// entity supports, in this order.
public enum HomeTileFeature: String, Equatable, Sendable, CaseIterable {
    case lightBrightness
    case coverOpenClose
    case targetTemperature
    case fanSpeed
    case alarmModes
    case lockCommands
}
