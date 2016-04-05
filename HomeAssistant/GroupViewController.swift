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

class GroupViewController: FormViewController {
    
    var groupsMap = [String:[String]]()
    
    var updatedStates = [String:JSON]()
    
    var receivedGroup = JSON([])
    
    var receivedEntities = JSON([])
    
    var sendingEntity = JSON([])
    
    var APIClientSharedInstance : HomeAssistantAPI!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.form
            +++ Section()
        for (_,entity):(String, JSON) in receivedEntities {
            let rowTag = entity["entity_id"].stringValue
            let entityType = getEntityType(rowTag)
            self.updatedStates[rowTag] = entity
            switch entityType {
            case "switch", "light", "input_boolean":
                self.form.last! <<< SwitchRow(rowTag) {
                    $0.title = entity["attributes"]["friendly_name"].stringValue
                    $0.value = (entity["state"].stringValue == "on") ? true : false
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            self.APIClientSharedInstance.turnOn(entity["entity_id"].stringValue)
                        } else {
                            self.APIClientSharedInstance.turnOff(entity["entity_id"].stringValue)
                        }
                    }.cellSetup { cell, row in
                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                        if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                          getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                              cell.imageView?.image = image
                          }
                        }
                    }
            case "script", "scene":
                self.form.last! <<< ButtonRow(rowTag) {
                    $0.title = entity["attributes"]["friendly_name"].stringValue
                    }.onCellSelection { cell, row -> Void in
                        self.APIClientSharedInstance.turnOn(entity["entity_id"].stringValue)
                    }.cellUpdate { cell, row in
                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                        if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                            getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                cell.imageView?.image = image
                            }
                        }
                    }
            case "weblink":
                if let url = NSURL(string: entity["state"].stringValue) {
                    self.form.last! <<< ButtonRow(rowTag) {
                        $0.title = entity["attributes"]["friendly_name"].stringValue
                        $0.presentationMode = .PresentModally(controllerProvider: ControllerProvider.Callback { return SFSafariViewController(URL: url, entersReaderIfAvailable: false) }, completionCallback: { vc in vc.navigationController?.popViewControllerAnimated(true) })
                        }.cellUpdate { cell, row in
                            cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                            if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                                getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                    cell.imageView?.image = image
                                }
                            }
                        }
                }
            case "binary_sensor", "sensor", "media_player", "thermostat", "sun":
                self.form.last! <<< ButtonRow(rowTag) {
                    $0.title = entity["attributes"]["friendly_name"].stringValue
                    $0.cellStyle = .Value1
                    $0.presentationMode = .Show(controllerProvider: ControllerProvider.Callback {
                        let attributesView = EntityAttributesViewController()
                        attributesView.entity = entity
                        return attributesView
                    }, completionCallback: {
                        vc in vc.navigationController?.popViewControllerAnimated(true)
                    })
                }.cellUpdate { cell, row in
                    cell.detailTextLabel?.text = self.updatedStates[rowTag]!["state"].stringValue.capitalizedString
                    if self.updatedStates[rowTag]!["attributes"]["unit_of_measurement"].exists() {
                        cell.detailTextLabel?.text = (self.updatedStates[rowTag]!["state"].stringValue + " " + self.updatedStates[rowTag]!["attributes"]["unit_of_measurement"].stringValue).capitalizedString
                    }
                    cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                    if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                        getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                            cell.imageView?.image = image
                        }
                    }
                }
            case "device_tracker":
                if entity["attributes"]["latitude"].exists() && entity["attributes"]["longitude"].exists() {
                    self.form.last! <<< LocationRow(rowTag) {
                        $0.title = entity["attributes"]["friendly_name"].stringValue
                        $0.value = CLLocation(latitude: entity["attributes"]["latitude"].doubleValue, longitude: entity["attributes"]["longitude"].doubleValue)
                        }.cellUpdate { cell, row in
                            var detailText = self.updatedStates[rowTag]!["state"].stringValue
                            if self.updatedStates[rowTag]!["state"].stringValue == "home" {
                                detailText = "Home"
                            } else if self.updatedStates[rowTag]!["state"].stringValue == "not_home" {
                                detailText = "Not home"
                            }
                            cell.detailTextLabel?.text = detailText
                            cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                            if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                                getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                    cell.imageView?.image = image
                                }
                            }
                    }
                } else {
                    self.form.last! <<< ButtonRow(rowTag) {
                        $0.title = entity["attributes"]["friendly_name"].stringValue
                        $0.cellStyle = .Value1
                        $0.presentationMode = .Show(controllerProvider: ControllerProvider.Callback {
                            let attributesView = EntityAttributesViewController()
                            attributesView.entity = entity
                            return attributesView
                        }, completionCallback: { vc in vc.navigationController?.popViewControllerAnimated(true) })
                        }.cellUpdate { cell, row in
                            cell.detailTextLabel?.text = self.updatedStates[rowTag]!["state"].stringValue.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                            if self.updatedStates[rowTag]!["attributes"]["unit_of_measurement"].exists() {
                                cell.detailTextLabel?.text = (self.updatedStates[rowTag]!["state"].stringValue + " " + self.updatedStates[rowTag]!["attributes"]["unit_of_measurement"].stringValue).stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                            }
                            cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                            if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                                getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                    cell.imageView?.image = image
                                }
                            }
                    }
                }
            case "input_select":
                self.form.last! <<< PickerInlineRow<String>(rowTag) {
                    $0.title = entity["attributes"]["friendly_name"].stringValue
                    $0.value = entity["state"].stringValue
                    $0.options = entity["attributes"]["options"].arrayObject as! [String]
                    }.onChange { row -> Void in
                        self.APIClientSharedInstance.CallService("input_select", service: "select_option", serviceData: ["entity_id": entity["entity_id"].stringValue, "option": row.value!])
                    }.cellUpdate { cell, row in
                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                        if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                            getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                cell.imageView?.image = image
                            }
                        }
                    }
            case "lock":
                self.form.last! <<< SwitchRow(rowTag) {
                    $0.title = entity["attributes"]["friendly_name"].stringValue
                    $0.value = (entity["state"].stringValue == "locked") ? true : false
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            self.APIClientSharedInstance.CallService("lock", service: "lock", serviceData: ["entity_id": entity["entity_id"].stringValue])
                        } else {
                            self.APIClientSharedInstance.CallService("lock", service: "unlock", serviceData: ["entity_id": entity["entity_id"].stringValue])
                        }
                    }.cellUpdate { cell, row in
                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                        if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                            getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                cell.imageView?.image = image
                            }
                        }
                    }
            case "garage_door":
                self.form.last! <<< SwitchRow(rowTag) {
                    $0.title = entity["attributes"]["friendly_name"].stringValue
                    $0.value = (entity["state"].stringValue == "open") ? true : false
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            self.APIClientSharedInstance.CallService("garage_door", service: "open", serviceData: ["entity_id": entity["entity_id"].stringValue])
                        } else {
                            self.APIClientSharedInstance.CallService("garage_door", service: "close", serviceData: ["entity_id": entity["entity_id"].stringValue])
                        }
                    }.cellUpdate { cell, row in
                        cell.imageView?.image = generateIconForEntity(self.updatedStates[rowTag]!)
                            if self.updatedStates[rowTag]!["attributes"]["entity_picture"].exists() {
                                getEntityPicture(self.updatedStates[rowTag]!["attributes"]["entity_picture"].stringValue).then { image in
                                    cell.imageView?.image = image
                                }
                            }
                        }
            default:
                print("We don't want this type", entityType)
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GroupViewController.StateChangedSSEEvent(_:)), name:"EntityStateChanged", object: nil)
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
        let rowTag = entityId
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
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "ShowEntityAttributes" {
            let entityAttributesViewController = segue.destinationViewController as! EntityAttributesViewController
            entityAttributesViewController.entity = sendingEntity
        }
    }
    
    
}

