import Foundation

/// A decoded `group/update`: the group this device plays in and whether it is playing.
struct SendspinGroupState: Decodable, Equatable {
    let playbackState: String
    let groupId: String
    let groupName: String

    enum CodingKeys: String, CodingKey {
        case playbackState = "playback_state"
        case groupId = "group_id"
        case groupName = "group_name"
    }

    var isPlaying: Bool { playbackState == "playing" }
}
