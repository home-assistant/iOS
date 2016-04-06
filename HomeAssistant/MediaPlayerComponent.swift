//
//  MediaPlayerComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

let isPlayingTransform = TransformOf<Bool, String>(fromJSON: { (value: String?) -> Bool? in
    return Bool(String(value!) == "playing")
    }, toJSON: { (value: Bool?) -> String? in
        if let value = value {
            if value == true {
                return "playing"
            } else {
                return "paused"
            }
        }
        return nil
})

class MediaPlayer: Entity {
    
    var IsPlaying: Bool?
    var IsVolumeMuted: Bool?
    var MediaContentID: String?
    var MediaContentType: String?
    var MediaDuration: Int?
    var MediaTitle: String?
    var VolumeLevel: Float?
    
    required init?(_ map: Map) {
        super.init(map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsPlaying        <- (map["state"], isPlayingTransform)
        IsVolumeMuted    <- map["attributes.is_volume_muted"]
        MediaContentID   <- map["attributes.media_content_id"]
        MediaContentType <- map["attributes.media_content_type"]
        MediaDuration    <- map["attributes.media_duration"]
        MediaTitle       <- map["attributes.media_title"]
        VolumeLevel      <- map["attributes.volume_level"]
    }
}