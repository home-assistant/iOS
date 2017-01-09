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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        if let entity = realm.object(ofType: Entity.self, forPrimaryKey: entityID as AnyObject) {
            self.title = (entity.FriendlyName != nil) ? entity.Name : "Attributes"

            form +++ Section {
                $0.tag = "entity_picture"
            }

            if let picture = entity.Picture {
                let _ = HomeAssistantAPI.sharedInstance.getImage(imageUrl: picture).then { image -> Void in
                    if let section = self.form.sectionBy(tag: "entity_picture") {
                        section.header = {
                            var header = HeaderFooterView<UIView>(.callback({
                                let imageView = UIImageView(image: image)
                                imageView.contentMode = .scaleAspectFit
                                return imageView
                            }))
                            header.height = { image.size.height }
                            return header
                        }()
                        section.reload()
                    }
                }
            }

            form +++ Section(header: "Attributes", footer: "")

            var attributes = entity.Attributes

            attributes["state"] = entity.State
            for attribute in attributes {
                let prettyLabel = attribute.0.replacingOccurrences(of: "_", with: " ").capitalized
                switch attribute.0 {
                case "fan":
                    if let thermostat = entity as? Thermostat {
                        form.last! <<< SwitchRow(attribute.0) {
                            $0.title = prettyLabel
                            $0.value = thermostat.Fan
                            }.onChange { row -> Void in
                                if row.value! {
                                    thermostat.turnFanOn()
                                } else {
                                    thermostat.turnFanOff()
                                }
                        }
                    }
                    break
                case "away_mode":
                    if let thermostat = entity as? Thermostat {
                        form.last! <<< SwitchRow(attribute.0) {
                            $0.title = prettyLabel
                            $0.value = thermostat.AwayMode
                            }.onChange { row -> Void in
                                if row.value! {
                                    thermostat.setAwayModeOn()
                                } else {
                                    thermostat.setAwayModeOff()
                                }
                        }
                    }
                    break
                case "temperature":
                    if let thermostat = entity as? Thermostat {
                        form.last! <<< SliderRow(attribute.0) {
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
                        form.last! <<< TextRow(attribute.0) {
                            $0.title = prettyLabel
                            $0.value = mediaPlayer.humanReadableMediaDuration()
                            $0.disabled = true
                        }
                    }
                    break
                case "is_volume_muted":
                    if let mediaPlayer = entity as? MediaPlayer {
                        form.last! <<< SwitchRow(attribute.0) {
                            $0.title = "Mute"
                            $0.value = mediaPlayer.IsVolumeMuted.value
                            }.onChange { row -> Void in
                                if row.value! {
                                    mediaPlayer.muteOn()
                                } else {
                                    mediaPlayer.muteOff()
                                }
                        }
                    }
                    break
                case "volume_level":
                    if let mediaPlayer = entity as? MediaPlayer {
                        if let volumeNumber = attribute.1 as? NSNumber {
                            let volume = Float(volumeNumber)*100
                            form.last! <<< SliderRow(attribute.0) {
                                $0.title = prettyLabel
                                $0.value = volume
                                $0.maximumValue = 100
                                $0.steps = 100
                                }.onChange { row -> Void in
                                    mediaPlayer.setVolume(row.value!)
                            }
                        }
                    }
                    break
                case "entity_picture", "icon", "supported_media_commands", "hidden", "assumed_state":
                    // Skip these attributes
                    break
                case "state":
                    if entity.Domain == "switch" || entity.Domain == "light" || entity.Domain == "input_boolean" {
                        form.last! <<< SwitchRow(attribute.0) {
                            $0.title = entity.Name
                            $0.value = (entity.State == "on") ? true : false
                            }.onChange { row -> Void in
                                if row.value! {
                                    let _ = HomeAssistantAPI.sharedInstance.turnOn(entityId: entity.ID)
                                } else {
                                    let _ = HomeAssistantAPI.sharedInstance.turnOff(entityId: entity.ID)
                                }
                        }
                    } else {
                        fallthrough
                    }
                default:
                    form.last! <<< TextRow(attribute.0) {
                        $0.title = prettyLabel
                        $0.value = String(describing: attribute.1).capitalized
                        $0.disabled = true
                    }
                }
            }
        }

        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self,
                                               // swiftlint:disable:next line_length
            selector: #selector(EntityAttributesViewController.StateChangedSSEEvent(_:)),
            name:NSNotification.Name(rawValue: "sse.state_changed"),
            object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func StateChangedSSEEvent(_ notification: NSNotification) {
        if let userInfo = (notification as NSNotification).userInfo {
            if let userInfoDict = userInfo as? [String : Any] {
                if let event = Mapper<StateChangedEvent>().map(JSON: userInfoDict) {
                    if event.EntityID != entityID { return }
                    if let entity = realm.object(ofType: Entity.self, forPrimaryKey: entityID as AnyObject) {
                        if let newState = event.NewState {
                            var updateDict: [String:Any] = [:]
                            newState.Attributes["state"] = entity.State
                            for (key, value) in newState.Attributes {
                                switch key {
                                case "fan":
                                    if let thermostat = entity as? Thermostat {
                                        if let fan = thermostat.Fan {
                                            updateDict[key] = fan
                                        }
                                    }
                                    break
                                case "away_mode":
                                    if let thermostat = entity as? Thermostat {
                                        if let awaymode = thermostat.AwayMode {
                                            updateDict[key] = awaymode
                                        }
                                    }
                                    break
                                case "temperature":
                                    if let thermostat = entity as? Thermostat {
                                        if let temperature = thermostat.Temperature {
                                            updateDict[key] = Float(temperature)
                                        }
                                    }
                                    break
                                case "media_duration":
                                    if let mediaPlayer = entity as? MediaPlayer {
                                        updateDict[key] = mediaPlayer.humanReadableMediaDuration()
                                    }
                                    break
                                case "is_volume_muted":
                                    if let mediaPlayer = entity as? MediaPlayer {
                                        updateDict[key] = mediaPlayer.IsVolumeMuted
                                    }
                                    break
                                case "volume_level":
                                    if let mediaPlayer = entity as? MediaPlayer {
                                        if let level = mediaPlayer.VolumeLevel.value {
                                            updateDict[key] = Float(level) * Float(100.0)
                                        }
                                    }
                                    break
                                case "entity_picture", "icon", "supported_media_commands", "hidden", "assumed_state":
                                    // Skip these attributes
                                    break
                                case "state":
                                    if entity.Domain == "switch" ||
                                        entity.Domain == "light" ||
                                        entity.Domain == "input_boolean" {
                                        updateDict["state"] = (entity.State == "on") as Bool
                                    } else {
                                        fallthrough
                                    }
                                    break
                                default:
                                    updateDict[key] = String(describing: value)
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
    }
    // swiftlint:enable cyclomatic_complexity
}
