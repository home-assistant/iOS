//
//  EntityAttributesViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/4/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import ObjectMapper
import RealmSwift

class EntityAttributesViewController: FormViewController {

    var entityID: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let entity = realm.objectForPrimaryKey(Entity.self, key: entityID)
        
        self.title = (entity?.FriendlyName != nil) ? entity?.Name : "Attributes"
        
        if let picture = entity!.Picture {
            form +++ Section()
                <<< TextAreaRow("entity_picture"){
                    $0.disabled = true
                    $0.cell.textView.scrollEnabled = false
                    $0.cell.textView.backgroundColor = .clearColor()
                    $0.cell.backgroundColor = .clearColor()
                }.cellUpdate { cell, row in
                    HomeAssistantAPI.sharedInstance.getImage(picture).then { image -> Void in
                        let attachment = NSTextAttachment()
                        attachment.image = image
                        attachment.bounds = CGRectMake(0, 0, image.size.width, image.size.height)
                        let attString = NSAttributedString(attachment: attachment)
                        let result = NSMutableAttributedString(attributedString: attString)
                        
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .Center
                        
                        let attrs:[String:AnyObject] = [NSParagraphStyleAttributeName: paragraphStyle]
                        let range = NSMakeRange(0, result.length)
                        result.addAttributes(attrs, range: range)
                        
                        cell.textView.textStorage.setAttributedString(result)
                        cell.height = { attachment.bounds.height + 20 }
                        self.tableView?.beginUpdates()
                        self.tableView?.endUpdates()
                    }
                }
        }
        
        form +++ Section(header: "Attributes", footer: "")
        
        var attributes = entity!.Attributes
        
        attributes["state"] = entity?.State
        for attribute in attributes {
            let prettyLabel = attribute.0.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
            switch attribute.0 {
            case "fan":
                if let thermostat = entity as? Thermostat {
                    form.last! <<< SwitchRow(attribute.0){
                        $0.title = prettyLabel
                        $0.value = thermostat.Fan
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            thermostat.turnFanOn()
                        } else {
                            thermostat.turnFanOff()
                        }
                    }
                }
                break
            case "away_mode":
                if let thermostat = entity as? Thermostat {
                    form.last! <<< SwitchRow(attribute.0){
                        $0.title = prettyLabel
                        $0.value = thermostat.AwayMode
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            thermostat.setAwayModeOn()
                        } else {
                            thermostat.setAwayModeOff()
                        }
                    }
                }
                break
            case "temperature":
                if let thermostat = entity as? Thermostat {
                    form.last! <<< SliderRow(attribute.0){
                        $0.title = prettyLabel
                        $0.value = Float(thermostat.Temperature!)
                        $0.maximumValue = 120.0
                        $0.steps = 120
                    }.onChange { row -> Void in
                        thermostat.setTemperature(row.value!)
                    }
                }
                break
            case "media_duration":
                if let mediaPlayer = entity as? MediaPlayer {
                    form.last! <<< TextRow(attribute.0){
                        $0.title = prettyLabel
                        $0.value = mediaPlayer.humanReadableMediaDuration()
                        $0.disabled = true
                    }
                }
                break
            case "is_volume_muted":
                if let mediaPlayer = entity as? MediaPlayer {
                    form.last! <<< SwitchRow(attribute.0){
                        $0.title = "Mute"
                        $0.value = mediaPlayer.IsVolumeMuted.value
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            mediaPlayer.muteOn()
                        } else {
                            mediaPlayer.muteOff()
                        }
                    }
                }
                break
            case "volume_level":
                if let mediaPlayer = entity as? MediaPlayer {
                    let volume = Float(attribute.1 as! NSNumber)*100
                    form.last! <<< SliderRow(attribute.0){
                        $0.title = prettyLabel
                        $0.value = volume
                        $0.maximumValue = 100
                        $0.steps = 100
                    }.onChange { row -> Void in
                        mediaPlayer.setVolume(row.value!)
                    }
                }
                break
            case "entity_picture", "icon", "supported_media_commands", "hidden", "assumed_state":
                // Skip these attributes
                break
            case "state":
                if entity?.Domain == "switch" || entity?.Domain == "light" || entity?.Domain == "input_boolean" {
                    form.last! <<< SwitchRow(attribute.0) {
                        $0.title = entity?.Name
                        $0.value = (entity?.State == "on") ? true : false
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            HomeAssistantAPI.sharedInstance.turnOn(entity!.ID)
                        } else {
                            HomeAssistantAPI.sharedInstance.turnOff(entity!.ID)
                        }
                    }
                } else {
                    fallthrough
                }
            default:
                form.last! <<< TextRow(attribute.0){
                    $0.title = prettyLabel
                    $0.value = String(attribute.1).capitalizedString
                    $0.disabled = true
                }
            }
        }
        
        
        // Do any additional setup after loading the view.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EntityAttributesViewController.StateChangedSSEEvent(_:)), name:"sse.state_changed", object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    func StateChangedSSEEvent(notification: NSNotification){
        if let userInfo = notification.userInfo {
            if let event = Mapper<StateChangedEvent>().map(userInfo) {
                if event.EntityID != entityID { return }
                let entity = realm.objectForPrimaryKey(Entity.self, key: entityID)
                if let newState = event.NewState {
                    var updateDict : [String:AnyObject] = [:]
                    newState.Attributes["state"] = entity?.State
                    for (key, value) in newState.Attributes {
                        switch key {
                        case "fan":
                            updateDict[key] = (entity as! Thermostat).Fan!
                            break
                        case "away_mode":
                            updateDict[key] = (entity as! Thermostat).AwayMode!
                            break
                        case "temperature":
                            updateDict[key] = Float((entity as! Thermostat).Temperature!)
                            break
                        case "media_duration":
                            updateDict[key] = (entity as! MediaPlayer).humanReadableMediaDuration()
                            break
                        case "is_volume_muted":
                            updateDict[key] = (entity as! MediaPlayer).IsVolumeMuted
                            break
                        case "volume_level":
                            updateDict[key] = Float(value as! NSNumber)*100
                            break
                        case "entity_picture", "icon", "supported_media_commands", "hidden", "assumed_state":
                            // Skip these attributes
                            break
                        case "state":
                            if entity?.Domain == "switch" || entity?.Domain == "light" || entity?.Domain == "input_boolean" {
                                updateDict["state"] = (entity?.State == "on") as Bool
                            } else {
                                fallthrough
                            }
                            break
                        default:
                            updateDict[key] = String(value)
                            break
                        }
                    }
                    // fatal error: can't unsafeBitCast between types of different sizes
                    self.form.setValues(updateDict)
                }
            }
        }
    }

}
