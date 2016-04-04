//
//  FirstViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import SafariServices
import Eureka
import SwiftyJSON
import MBProgressHUD
import Whisper
import PermissionScope
import FontAwesomeKit
import CoreLocation

class FirstViewController: FormViewController {
    
    let prefs = NSUserDefaults.standardUserDefaults()
    
    let pscope = PermissionScope()
    
    var groupsMap = [String:[String]]()
    
    var updatedStates = [String:JSON]()
    
    var sendingEntity = JSON([])
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if let locationName = prefs.stringForKey("location_name") {
            self.title = locationName
            let tabBarIcon = getIconForIdentifier("mdi:home", iconWidth: 20, iconHeight: 20, color: UIColor.grayColor())
            
            self.tabBarItem = UITabBarItem(title: locationName, image: tabBarIcon, tag: 0)
        }
        
        pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                             message: "We use this to let you\r\nsend notifications to your device.")
        pscope.addPermission(LocationAlwaysPermission(),
                             message: "We use this to track\r\nwhere you are and notify Home Assistant.")
        
        pscope.show({ finished, results in
            print("got results \(results)")
            if results[0].status == .Authorized {
                print("User authorized the use of notifications")
                UIApplication.sharedApplication().registerForRemoteNotifications()
            }
        }, cancelled: { (results) -> Void in
            print("thing was cancelled")
        })
        
        if let APIClientSharedInstance = (UIApplication.sharedApplication().delegate as! AppDelegate).APIClientSharedInstance {
            MBProgressHUD.showHUDAddedTo(self.view, animated: true)
            self.form
                +++ Section()
            APIClientSharedInstance.GetBootstrap().then { bootstrap -> Void in
                let sortedStates = bootstrap["states"].arrayValue.sort { $0["entity_id"].stringValue > $1["entity_id"].stringValue }
                let allGroups = bootstrap["states"].arrayValue.filter {
                    return getEntityType($0["entity_id"].stringValue) == "group"
                }
                var sectionCounts = ["ungrouped": 1]
                let sortedGroups = allGroups.sort { $0["attributes"]["order"].intValue < $1["attributes"]["order"].intValue }
                for group in sortedGroups {
                    if group["entity_id"].stringValue == "group.all_devices" || group["entity_id"].stringValue == "group.all_switches" || group["entity_id"].stringValue == "group.all_lights" {
                        continue
                    }
                    sectionCounts[group["entity_id"].stringValue] = 0
                    for (_,entity):(String, JSON) in group["attributes"]["entity_id"] {
                        if self.groupsMap[entity.stringValue] == nil {
                            self.groupsMap[entity.stringValue] = [String]()
                        }
                        self.groupsMap[entity.stringValue]!.append(group["entity_id"].stringValue)
                    }
                    self.form
                        +++ Section(header: group["attributes"]["friendly_name"].stringValue, footer: ""){
                            $0.tag = group["entity_id"].stringValue
                    }
                }
                self.form
                    +++ Section(header: "Ungrouped", footer: "\n\n"){
                        $0.tag = "ungrouped"
                    }
                for subJson in sortedStates {
                    let entityType = getEntityType(subJson["entity_id"].stringValue)
                    if entityType != "group" && subJson["attributes"]["hidden"].bool == true {
                        continue
                    }
                    var groupMapEntry = [String]()
                    if let groupMapTest = self.groupsMap[subJson["entity_id"].stringValue] {
                        groupMapEntry = groupMapTest
                    } else {
                        groupMapEntry = ["ungrouped"]
                    }
                    for groupToAdd in groupMapEntry {
                        let groupSection: Section = self.form.sectionByTag(groupToAdd)!
                        let rowTag = groupToAdd+"_"+subJson["entity_id"].stringValue
                        self.updatedStates[rowTag] = subJson
                        switch entityType {
                        case "switch", "light", "input_boolean":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< SwitchRow(rowTag) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = (subJson["state"].stringValue == "on") ? true : false
                                }.onChange { row -> Void in
                                    if (row.value == true) {
                                        APIClientSharedInstance.turnOn(subJson["entity_id"].stringValue)
                                    } else {
                                        APIClientSharedInstance.turnOff(subJson["entity_id"].stringValue)
                                    }
                                }.cellUpdate { cell, row in
                                    cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                }
                        case "script", "scene":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< ButtonRow(rowTag) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    }.onCellSelection { cell, row -> Void in
                                        APIClientSharedInstance.turnOn(subJson["entity_id"].stringValue)
                                    }.cellUpdate { cell, row in
                                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                    }
                        case "weblink":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            if let url = NSURL(string: subJson["state"].stringValue) {
                                groupSection
                                    <<< ButtonRow(rowTag) {
                                        $0.title = subJson["attributes"]["friendly_name"].stringValue
                                        $0.presentationMode = .PresentModally(controllerProvider: ControllerProvider.Callback { return SFSafariViewController(URL: url, entersReaderIfAvailable: false) }, completionCallback: { vc in vc.navigationController?.popViewControllerAnimated(true) })
                                        }.cellUpdate { cell, row in
                                            cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                        }
                            }
                        case "binary_sensor", "sensor", "media_player", "thermostat", "sun":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< PushRow<String>(rowTag) {
                                        $0.title = subJson["attributes"]["friendly_name"].stringValue
                                        $0.presentationMode = .SegueName(segueName: "ShowEntityAttributes", completionCallback: nil)
                                    }.cellSetup { cell, row in
                                        cell.detailTextLabel?.text = self.updatedStates[rowTag]!["state"].stringValue
                                    }.cellUpdate { cell, row in
                                        cell.detailTextLabel?.text = self.updatedStates[rowTag]!["state"].stringValue
                                        if self.updatedStates[rowTag]!["attributes"]["unit_of_measurement"].exists() {
                                            cell.detailTextLabel?.text = self.updatedStates[rowTag]!["state"].stringValue + " " + self.updatedStates[rowTag]!["attributes"]["unit_of_measurement"].stringValue
                                        }
                                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                    }
                        case "device_tracker":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< LocationRow(rowTag) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = CLLocation(latitude: subJson["attributes"]["latitude"].doubleValue, longitude: subJson["attributes"]["longitude"].doubleValue)
                                }.cellUpdate { cell, row in
                                    var detailText = self.updatedStates[rowTag]!["state"].stringValue
                                    if self.updatedStates[rowTag]!["state"].stringValue == "home" {
                                        detailText = "Home"
                                    } else if self.updatedStates[rowTag]!["state"].stringValue == "not_home" {
                                        detailText = "Not home"
                                    }
                                    cell.detailTextLabel?.text = detailText
                                    cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                }
                        case "input_select":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< PushRow<String>(rowTag) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = subJson["state"].stringValue
                                    $0.options = subJson["attributes"]["options"].arrayObject as! [String]
                                }.onChange { row -> Void in
                                    APIClientSharedInstance.CallService("input_select", service: "select_option", serviceData: ["entity_id": subJson["entity_id"].stringValue, "option": row.value!])
                                }.cellUpdate { cell, row in
                                    cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                }
                        case "lock":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< SwitchRow(rowTag) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = (subJson["state"].stringValue == "locked") ? true : false
                                }.onChange { row -> Void in
                                    if (row.value == true) {
                                        APIClientSharedInstance.CallService("lock", service: "lock", serviceData: ["entity_id": subJson["entity_id"].stringValue])
                                    } else {
                                        APIClientSharedInstance.CallService("lock", service: "unlock", serviceData: ["entity_id": subJson["entity_id"].stringValue])
                                    }
                                }.cellUpdate { cell, row in
                                    cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                }
                        case "garage_door":
                            sectionCounts[groupToAdd]! = sectionCounts[groupToAdd]! + 1
                            groupSection
                                <<< SwitchRow(rowTag) {
                                    $0.title = subJson["attributes"]["friendly_name"].stringValue
                                    $0.value = (subJson["state"].stringValue == "open") ? true : false
                                }.onChange { row -> Void in
                                    if (row.value == true) {
                                        APIClientSharedInstance.CallService("garage_door", service: "open", serviceData: ["entity_id": subJson["entity_id"].stringValue])
                                    } else {
                                        APIClientSharedInstance.CallService("garage_door", service: "close", serviceData: ["entity_id": subJson["entity_id"].stringValue])
                                    }
                                }.cellUpdate { cell, row in
                                    cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                                }
                        default:
                            print("We don't want this type", entityType)
                        }
                    }
                }
                for (name, count) in sectionCounts {
                    if count < 1 {
                        let sectionToHide : Section = self.form.sectionByTag(name)!
                        sectionToHide.hidden = true
                        sectionToHide.evaluateHidden()
                    }
                }
            }
        } else {
            print("API client not ready, skipping!!!")
        }
        
        MBProgressHUD.hideAllHUDsForView(self.view, animated: true)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(FirstViewController.StateChangedSSEEvent(_:)), name:"EntityStateChanged", object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func StateChangedSSEEvent(notification: NSNotification){
//        print("notification", notification)
        let json = JSON(notification.userInfo!)
        let entityId = json["data"]["entity_id"].stringValue
        let entityType = getEntityType(json["data"]["entity_id"].stringValue)
        let friendly_name = json["data"]["new_state"]["attributes"]["friendly_name"].stringValue
        let newState = json["data"]["new_state"]["state"].stringValue
        var subtitleString = friendly_name+" is now "+newState+". It was "+json["data"]["old_state"]["state"].stringValue
        if json["data"]["new_state"]["attributes"]["unit_of_measurement"].exists() && json["data"]["old_state"]["attributes"]["unit_of_measurement"].exists() {
            subtitleString = newState + " " + json["data"]["new_state"]["attributes"]["unit_of_measurement"].stringValue+". It was "+json["data"]["old_state"]["state"].stringValue + " " + json["data"]["old_state"]["attributes"]["unit_of_measurement"].stringValue
        }
        let icon = generateIconForEntity(json["data"]["new_state"])
        let announcement = Announcement(title: friendly_name, subtitle: subtitleString, image: icon)
        Shout(announcement, to: self)
        var groupMapEntry = [String]()
        if let groupMapTest = self.groupsMap[entityId] {
            groupMapEntry = groupMapTest
        } else {
            groupMapEntry = ["ungrouped"]
        }
        for group in groupMapEntry {
            let rowTag = group+"_"+entityId
            self.updatedStates[rowTag] = json["data"]["new_state"]
            if entityType == "switch" || entityType == "light" || entityType == "input_boolean" {
                if let row : SwitchRow = self.form.rowByTag(rowTag) {
                    row.value = (newState == "on") ? true : false
                    row.cell.imageView?.image = icon
                    row.updateCell()
                    row.reload()
                }
            } else {
                if let row : LabelRow = self.form.rowByTag(rowTag) {
                    row.value = newState
                    if json["data"]["new_state"]["attributes"]["unit_of_measurement"].exists() {
                        row.value = newState + " " + json["data"]["new_state"]["attributes"]["unit_of_measurement"].stringValue
                    }
                    row.cell.imageView?.image = icon
                    row.updateCell()
                    row.reload()
                }
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "ShowEntityAttributes" {
            let entityAttributesViewController = segue.destinationViewController as! EntityAttributesViewController
            entityAttributesViewController.entity = sendingEntity
        }
    }


}

