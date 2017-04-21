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
import MBProgressHUD

class EntityAttributesViewController: FormViewController {

    var entityID: String = ""

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        if let entity = realm.object(ofType: Entity.self, forPrimaryKey: entityID as AnyObject) {
            self.title = (entity.FriendlyName != nil) ? entity.Name : "Attributes"

            if let picture = entity.DownloadedPicture {
                form +++ Section {
                    $0.tag = "entity_picture"
                    $0.header = {
                        var header = HeaderFooterView<UIView>(.callback({
                            let imageView = UIImageView(image: picture)
                            imageView.contentMode = .scaleAspectFit
                            return imageView
                        }))
                        header.height = { picture.size.height }
                        return header
                    }()
                }
            } else if let picture = entity.Picture {
                var hud: MBProgressHUD?
                let entityPictureSection = Section {
                    $0.tag = "entity_picture"
                    $0.header = {
                        var header = HeaderFooterView<UIView>(.callback({
                            let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
                            hud = MBProgressHUD.showAdded(to: view, animated: true)
                            hud?.detailsLabel.text = "Loading picture..."
                            return view
                        }))
                        header.height = { 200 }
                        return header
                    }()
                }
                form +++ entityPictureSection
                _ = HomeAssistantAPI.sharedInstance.getImage(imageUrl: picture).then { image -> Void in
                    hud?.hide(animated: true)
                    entityPictureSection.header = {
                        var header = HeaderFooterView<UIView>(.callback({
                            let imageView = UIImageView(image: image)
                            imageView.contentMode = .scaleAspectFit
                            return imageView
                        }))
                        header.height = { image.size.height }
                        return header
                    }()
                    entityPictureSection.reload()
                    }.catch { _ in
                        hud?.hide(animated: true)
                        entityPictureSection.hidden = true
                        entityPictureSection.evaluateHidden()
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
                                    _ = HomeAssistantAPI.sharedInstance.turnOn(entityId: entity.ID)
                                } else {
                                    _ = HomeAssistantAPI.sharedInstance.turnOff(entityId: entity.ID)
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
