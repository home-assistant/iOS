import Foundation

/// The `controller` object of `client/command`, used to drive the group this device plays in.
struct SendspinControllerCommand: Encodable, Equatable {
    let command: String
    let volume: Int?
    let mute: Bool?
    let positionMs: Int?
    let offsetMs: Int?

    enum CodingKeys: String, CodingKey {
        case command
        case volume
        case mute
        case positionMs = "position_ms"
        case offsetMs = "offset_ms"
    }

    init(command: String, volume: Int? = nil, mute: Bool? = nil, positionMs: Int? = nil, offsetMs: Int? = nil) {
        self.command = command
        self.volume = volume
        self.mute = mute
        self.positionMs = positionMs
        self.offsetMs = offsetMs
    }

    static let play = SendspinControllerCommand(command: "play")
    static let pause = SendspinControllerCommand(command: "pause")
    static let stop = SendspinControllerCommand(command: "stop")
    static let next = SendspinControllerCommand(command: "next")
    static let previous = SendspinControllerCommand(command: "previous")

    static func seek(positionMs: Int) -> SendspinControllerCommand {
        SendspinControllerCommand(command: "seek", positionMs: positionMs)
    }
}
