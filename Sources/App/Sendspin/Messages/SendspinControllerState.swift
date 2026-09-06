import Foundation

/// A decoded `controller` state object: what the group this device belongs to currently supports
/// and reports.
struct SendspinControllerState: Decodable, Equatable {
    let supportedCommands: [String]
    let volume: Int
    let muted: Bool
    /// One of `off`, `one` or `all`.
    let repeatMode: String
    let shuffle: Bool
    let seekMaxMs: Int?

    enum CodingKeys: String, CodingKey {
        case supportedCommands = "supported_commands"
        case volume
        case muted
        case repeatMode = "repeat"
        case shuffle
        case seekMaxMs = "seek_max_ms"
    }

    func supports(_ command: String) -> Bool {
        supportedCommands.contains(command)
    }
}
