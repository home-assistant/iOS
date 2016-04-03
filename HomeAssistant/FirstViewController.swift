//
//  FirstViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import SwiftyJSON
import MBProgressHUD
import Whisper

class FirstViewController: FormViewController {
    
    override func viewDidLoad() {
        let prefs = NSUserDefaults.standardUserDefaults()

        super.viewDidLoad()
        
        if let baseURL = prefs.stringForKey("baseURL") {
            let APIClientSharedInstance = HomeAssistantAPI(baseAPIUrl: baseURL, APIPassword: prefs.stringForKey("apiPassword")!)
            MBProgressHUD.showHUDAddedTo(self.view, animated: true)
            self.form
                +++ Section()
            APIClientSharedInstance.GetBootstrap().then { bootstrap -> Void in
                self.title = bootstrap["config"]["location_name"].stringValue
                let sortedStates = bootstrap["states"].arrayValue.sort { $0["entity_id"].stringValue > $1["entity_id"].stringValue }
                var groupsMap = [String:[String]]()
                let allGroups = bootstrap["states"].arrayValue.filter {
                    return APIClientSharedInstance.getEntityType($0["entity_id"].stringValue) == "group"
                }
                let sortedGroups = allGroups.sort { $0["attributes"]["order"].intValue < $1["attributes"]["order"].intValue }
                for group in sortedGroups {
                    if group["entity_id"].stringValue == "group.all_devices" || group["entity_id"].stringValue == "group.all_switches" || group["entity_id"].stringValue == "group.all_lights" {
                        continue
                    }
                    for (_,entity):(String, JSON) in group["attributes"]["entity_id"] {
                        if groupsMap[entity.stringValue] == nil {
                            groupsMap[entity.stringValue] = [String]()
                        }
                        groupsMap[entity.stringValue]!.append(group["entity_id"].stringValue)
                    }
                    self.form
                        +++ Section(header: group["attributes"]["friendly_name"].stringValue, footer: ""){
                            $0.tag = group["entity_id"].stringValue
                    }
                }
                self.form
                    +++ Section(header: "Ungrouped", footer: ""){
                        $0.tag = "ungrouped"
                }
                for subJson in sortedStates {
                    let entityType = APIClientSharedInstance.getEntityType(subJson["entity_id"].stringValue)
                    if entityType != "group" && subJson["attributes"]["hidden"].bool == true {
                        continue
                    }
                    var groupMapEntry = [String]()
                    if let groupMapTest = groupsMap[subJson["entity_id"].stringValue] {
                        groupMapEntry = groupMapTest
                    } else {
                        groupMapEntry = ["ungrouped"]
                    }
                    for groupToAdd in groupMapEntry {
                        let groupSection: Section = self.form.sectionByTag(groupToAdd)!
                        switch entityType {
                        case "switch", "light":
                            groupSection
                                <<< SwitchRow(subJson["entity_id"].stringValue) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = (subJson["state"].stringValue == "on") ? true : false
                                    }.onChange { row -> Void in
                                        if (row.value == true) {
                                            APIClientSharedInstance.turnOn(row.tag!)
                                        } else {
                                            APIClientSharedInstance.turnOff(row.tag!)
                                        }
                            }
                        case "binary_sensor", "sensor", "device_tracker", "media_player":
                            groupSection
                                <<< LabelRow(subJson["entity_id"].stringValue) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = subJson["state"].stringValue
                                    if entityType == "sensor" {
                                        $0.value = subJson["state"].stringValue + " " + subJson["attributes"]["unit_of_measurement"].stringValue
                                    }
                            }
                        default:
                            print("We don't want this type", entityType)
                        }
                    }
                }
            }
            MBProgressHUD.hideAllHUDsForView(self.view, animated: true)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(FirstViewController.StateChangedSSEEvent(_:)), name:"EntityStateChanged", object: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func StateChangedSSEEvent(notification: NSNotification){
        //Take Action on Notification
        print("notification", notification)
        let json = JSON(notification.userInfo!)
        let entityId = json["data"]["entity_id"].stringValue
        let entityType = getEntityType(json["data"]["entity_id"].stringValue)
        let friendly_name = json["data"]["new_state"]["attributes"]["friendly_name"].stringValue
        let newState = json["data"]["new_state"]["state"].stringValue
        var subtitleString = friendly_name+" is now "+newState+". It was "+json["data"]["old_state"]["state"].stringValue
        if entityType == "sensor" {
            subtitleString = newState + " " + json["data"]["new_state"]["attributes"]["unit_of_measurement"].stringValue+". It was "+json["data"]["old_state"]["state"].stringValue + " " + json["data"]["old_state"]["attributes"]["unit_of_measurement"].stringValue
        }
        let announcement = Announcement(title: friendly_name, subtitle: subtitleString)
        Shout(announcement, to: self)
        if entityType == "switch" || entityType == "light" {
            if let row : SwitchRow = self.form.rowByTag(entityId) {
                row.value = (newState == "on") ? true : false
                row.updateCell()
            }
        } else {
            if let row : LabelRow = self.form.rowByTag(entityId) {
                row.value = newState
                if entityType == "sensor" {
                    row.value = newState + " " + json["data"]["new_state"]["attributes"]["unit_of_measurement"].stringValue
                }
                row.updateCell()
            }
        }
    }


}

