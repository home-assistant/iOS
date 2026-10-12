import Foundation

/// The `controller` object of `client/command`.
struct SendspinControllerCommand: Codable, Equatable {
    let command: String
    let volume: Int?
    let mute: Bool?

    init(command: String, volume: Int? = nil, mute: Bool? = nil) {
        self.command = command
        self.volume = volume
        self.mute = mute
    }
}
