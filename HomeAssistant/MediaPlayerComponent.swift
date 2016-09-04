//
//  MediaPlayerComponent.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift

class MediaPlayer: SwitchableEntity {
    
    dynamic var IsPlaying: Bool = false
    dynamic var IsIdle: Bool = false
    var IsVolumeMuted = RealmOptional<Bool>()
    dynamic var MediaContentID: String? = nil
    dynamic var MediaContentType: String? = nil
    var MediaDuration = RealmOptional<Int>()
    dynamic var MediaTitle: String? = nil
    var VolumeLevel = RealmOptional<Float>()
    
    override func mapping(map: Map) {
        super.mapping(map)
        
        IsPlaying        <- (map["state"], ComponentBoolTransform(trueValue: "playing", falseValue: "paused"))
        IsIdle           <- (map["state"], ComponentBoolTransform(trueValue: "idle", falseValue: ""))
        IsVolumeMuted    <- map["attributes.is_volume_muted"]
        MediaContentID   <- map["attributes.media_content_id"]
        MediaContentType <- map["attributes.media_content_type"]
        MediaDuration    <- map["attributes.media_duration"]
        MediaTitle       <- map["attributes.media_title"]
        VolumeLevel      <- map["attributes.volume_level"]
    }
    
    func humanReadableMediaDuration() -> String {
        if let durationSeconds = self.MediaDuration.value {
            let hours = durationSeconds / 3600
            let minutes = (durationSeconds % 3600) / 60
            let seconds = (durationSeconds % 3600) % 60
            return "\(hours):\(minutes):\(seconds)"
        } else {
            return "00:00:00"
        }
    }
    
    func muteOn() {
        HomeAssistantAPI.sharedInstance.CallService("media_player", service: "volume_mute", serviceData: ["entity_id": self.ID, "is_volume_muted": "on"])
    }
    func muteOff() {
        HomeAssistantAPI.sharedInstance.CallService("media_player", service: "volume_mute", serviceData: ["entity_id": self.ID, "is_volume_muted": "off"])
    }
    func setVolume(newVolume: Float) {
        let fixedVolume = newVolume/100
        HomeAssistantAPI.sharedInstance.CallService("media_player", service: "volume_set", serviceData: ["entity_id": self.ID, "volume_level": fixedVolume])
    }
    
    override var ComponentIcon: String {
        return "mdi:cast"
    }
    
    override func StateIcon() -> String {
        return (self.State != "off" && self.State != "idle") ? "mdi:cast-connected" : "mdi:cast"
    }
}