import Foundation

/// `group/update`: the group this device plays in.
struct SendspinGroupUpdate: Codable, Equatable {
    let playbackState: String
    let groupID: String
    let groupName: String

    enum CodingKeys: String, CodingKey {
        case playbackState = "playback_state"
        case groupID = "group_id"
        case groupName = "group_name"
    }
}
