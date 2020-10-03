//
//  RemotePlayerState.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 5/15/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

// To parse the JSON, add this file to your project and do:
//
//   let remotePlayerState = try? newJSONDecoder().decode(RemotePlayerState.self, from: jsonData)

import Foundation

public class RemotePlayerState: Codable {
    public let State: String
    public let VolumeLevel: Double
    public let Muted: Bool
    public let ContentID: String
    public let ContentType: String

    enum CodingKeys: String, CodingKey {
        case State = "state"
        case VolumeLevel = "volume_level"
        case Muted = "is_volume_muted"
        case ContentID = "media_content_id"
        case ContentType = "media_content_type"
    }

    public init(state: String, mediaVolumeLevel: Double, isVolumeMuted: Bool,
                mediaContentID: String, mediaContentType: String) {
        self.State = state
        self.VolumeLevel = mediaVolumeLevel
        self.Muted = isVolumeMuted
        self.ContentID = mediaContentID
        self.ContentType = mediaContentType
    }
}
