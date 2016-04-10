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
        
        form +++ Section()
        
        form.last! <<< TextRow("state"){
            $0.title = "State"
            $0.value = entity!.State
            $0.disabled = true
        }
        
        print("Entity", entity!.Attributes)
        
        if let attributes = entity?.Attributes {
            for attribute in attributes {
                print("Attribute", attribute)
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
                        }.onChange { row -> Void in
                            mediaPlayer.setVolume(row.value!)
                        }
                        break
                    default:
                        form.last! <<< TextRow(attribute.0){
                            $0.title = prettyLabel
                            $0.value = String(attribute.1)
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
