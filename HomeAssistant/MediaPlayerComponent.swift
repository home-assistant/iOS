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
    dynamic var Source: String? = nil
    dynamic var SourceList: [String] = [String]()
    let StoredSourceList = List<StringObject>()
    
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        
        IsPlaying        <- (map["state"], ComponentBoolTransform(trueValue: "playing", falseValue: "paused"))
        IsIdle           <- (map["state"], ComponentBoolTransform(trueValue: "idle", falseValue: ""))
        IsVolumeMuted.value    <- map["attributes.is_volume_muted"]
        MediaContentID   <- map["attributes.media_content_id"]
        MediaContentType <- map["attributes.media_content_type"]
        MediaDuration.value    <- map["attributes.media_duration"]
        MediaTitle       <- map["attributes.media_title"]
        Source           <- map["attributes.source"]
        VolumeLevel.value      <- map["attributes.volume_level"]
        SourceList       <- map["attributes.source_list"]
        
        var StoredSourceList: [String]? = nil
        StoredSourceList     <- map["attributes.source_list"]
        StoredSourceList?.forEach { option in
            let value = StringObject()
            value.value = option
            self.StoredSourceList.append(value)
        }
    }
    
    override class func ignoredProperties() -> [String] {
        return ["SourceList"]
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
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "media_player", service: "volume_mute", serviceData: ["entity_id": self.ID as AnyObject, "is_volume_muted": "on" as AnyObject])
    }
    func muteOff() {
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "media_player", service: "volume_mute", serviceData: ["entity_id": self.ID as AnyObject, "is_volume_muted": "off" as AnyObject])
    }
    func setVolume(_ newVolume: Float) {
        let fixedVolume = newVolume/100
        let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "media_player", service: "volume_set", serviceData: ["entity_id": self.ID as AnyObject, "volume_level": fixedVolume as AnyObject])
    }
    
    override var ComponentIcon: String {
        return "mdi:cast"
    }
    
    override func StateIcon() -> String {
        return (self.State != "off" && self.State != "idle") ? "mdi:cast-connected" : "mdi:cast"
    }
}
