//
//  EntityAttributesViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/4/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka

class EntityAttributesViewController: FormViewController {

    var entity: Entity?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if entity?.FriendlyName != nil {
            self.title = entity?.FriendlyName
        } else {
            self.title = "Attributes"
        }
        
        if let picture = self.entity?.Picture {
            form +++ Section()
                <<< TextAreaRow("entity_picture"){
                    $0.disabled = true
                    $0.cell.textView.scrollEnabled = false
                    $0.cell.textView.backgroundColor = .clearColor()
                    $0.cell.backgroundColor = .clearColor()
                }.cellUpdate { cell, row in
                    (UIApplication.sharedApplication().delegate as! AppDelegate).APIClientSharedInstance.getImage(picture).then { image -> Void in
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
        
        if var attributes = entity?.Attributes {
            attributes["state"] = entity?.State
            for attribute in attributes {
                let prettyLabel = attribute.0.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                switch attribute.0 {
                    case "fan":
                        let thermostat = entity as! Thermostat
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
                        break
                    case "away_mode":
                        let thermostat = entity as! Thermostat
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
                        break
                    case "temperature":
                        let thermostat = entity as! Thermostat
                        form.last! <<< SliderRow(attribute.0){
                            $0.title = prettyLabel
                            $0.value = Float(thermostat.Temperature!)
                            $0.maximumValue = 120.0
                            $0.steps = 120
                            
                        }.onChange { row -> Void in
                            thermostat.setTemperature(row.value!)
                        }
                        break
                    case "media_duration":
                        let mediaPlayer = entity as! MediaPlayer
                        form.last! <<< TextRow(attribute.0){
                            $0.title = prettyLabel
                            $0.value = mediaPlayer.humanReadableMediaDuration()
                            $0.disabled = true
                        }
                        break
                    case "is_volume_muted":
                        let mediaPlayer = entity as! MediaPlayer
                        form.last! <<< SwitchRow(attribute.0){
                            $0.title = "Mute"
                            $0.value = mediaPlayer.IsVolumeMuted
                        }.onChange { row -> Void in
                            if (row.value == true) {
                                mediaPlayer.muteOn()
                            } else {
                                mediaPlayer.muteOff()
                            }
                        }
                        break
                    case "volume_level":
                        let mediaPlayer = entity as! MediaPlayer
                        let volume = Float(attribute.1 as! NSNumber)*100
                        form.last! <<< SliderRow(attribute.0){
                            $0.title = prettyLabel
                            $0.value = volume
                            $0.maximumValue = 100
                            $0.steps = 100
                        }.onChange { row -> Void in
                            mediaPlayer.setVolume(row.value!)
                        }
                        break
                    case "entity_picture", "icon", "supported_media_commands":
                        // Skip these attributes
                        break
                    case "state":
                        if entity?.Domain == "switch" || entity?.Domain == "light" || entity?.Domain == "input_boolean" {
                            form.last! <<< SwitchRow(attribute.0) {
                                $0.title = entity?.FriendlyName
                                $0.value = (entity?.State == "on") ? true : false
                            }.onChange { row -> Void in
                                if (row.value == true) {
                                    (UIApplication.sharedApplication().delegate as! AppDelegate).APIClientSharedInstance.turnOn(self.entity!.ID)
                                } else {
                                    (UIApplication.sharedApplication().delegate as! AppDelegate).APIClientSharedInstance.turnOff(self.entity!.ID)
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
        }
        
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
