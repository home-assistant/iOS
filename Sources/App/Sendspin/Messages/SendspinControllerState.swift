import Foundation

/// The `controller` object of `server/state`: what the group currently lets this device do.
struct SendspinControllerState: Codable, Equatable {
    let supportedCommands: [String]
    let volume: Int
    let muted: Bool
    let `repeat`: String
    let shuffle: Bool
    let seekMaxMs: Int64?

    enum CodingKeys: String, CodingKey {
        case supportedCommands = "supported_commands"
        case volume
        case muted
        case `repeat`
        case shuffle
        case seekMaxMs = "seek_max_ms"
    }
}
