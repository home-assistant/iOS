//
//  GroupViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import SafariServices
import Eureka
import CoreLocation
import ObjectMapper

class GroupViewController: FormViewController {
    
    var groupsMap = [String:[String]]()
    
    var updatedStates = [String:Entity]()
    
    var receivedGroup : Group?
    
    var receivedEntities = [Entity]()
    
    var sendingEntity : Entity?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.form
            +++ Section()
        for entity in receivedEntities {
            let rowTag = entity.ID
            self.updatedStates[rowTag] = entity
            switch entity.Domain {
//            case "switch", "light", "input_boolean":
//                self.form.last! <<< SwitchRow(rowTag) {
//                    $0.title = entity.FriendlyName
//                    $0.value = (entity.State == "on") ? true : false
//                    }.onChange { row -> Void in
//                        if (row.value == true) {
//                            HomeAssistantAPI.sharedInstance.turnOn(entity.ID)
//                        } else {
//                            HomeAssistantAPI.sharedInstance.turnOff(entity.ID)
//                        }
//                    }.cellSetup { cell, row in
//                        if let updatedState = self.updatedStates[rowTag] {
//                            cell.imageView?.image = entity.EntityIcon()
//                            if let picture = updatedState.DownloadedPicture {
//                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
//                            }
//                        }
//                }
            case "script", "scene":
                self.form.last! <<< ButtonRow(rowTag) {
                    $0.title = entity.FriendlyName
                    }.onCellSelection { cell, row -> Void in
                        HomeAssistantAPI.sharedInstance.turnOn(entity.ID)
                    }.cellUpdate { cell, row in
                        if let updatedState = self.updatedStates[rowTag] {
                            cell.imageView?.image = entity.EntityIcon()
                            if let picture = updatedState.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                        }
                }
            case "weblink":
                if let url = NSURL(string: entity.State) {
                    self.form.last! <<< ButtonRow(rowTag) {
                        $0.title = entity.FriendlyName
                        if url.scheme == "http" || url.scheme == "https" {
                            $0.presentationMode = .PresentModally(controllerProvider: ControllerProvider.Callback { return SFSafariViewController(URL: url, entersReaderIfAvailable: false) }, completionCallback: { vc in vc.navigationController?.popViewControllerAnimated(true) })
                        }
                        }.cellUpdate { cell, row in
                            if let updatedState = self.updatedStates[rowTag] {
                                cell.imageView?.image = entity.EntityIcon()
                                if let picture = updatedState.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                            }
                        }.onCellSelection { cell, row -> Void in
                            if url.scheme != "http" && url.scheme != "https" {
                                UIApplication.sharedApplication().openURL(url)
                            }
                    }
                }
            case "switch", "light", "input_boolean", "binary_sensor", "camera", "sensor", "media_player", "thermostat", "sun":
                self.form.last! <<< ButtonRow(rowTag) {
                    $0.title = entity.FriendlyName
                    $0.cellStyle = .Value1
                    $0.presentationMode = .Show(controllerProvider: ControllerProvider.Callback {
                        let attributesView = EntityAttributesViewController()
                        attributesView.entity = self.updatedStates[rowTag]
                        return attributesView
                        }, completionCallback: {
                            vc in vc.navigationController?.popViewControllerAnimated(true)
                    })
                    }.cellUpdate { cell, row in
                        if let updatedState = self.updatedStates[rowTag] {
                            cell.detailTextLabel?.text = updatedState.State.capitalizedString
                            if let sensor = updatedState as? Sensor {
                                if let uom = sensor.UnitOfMeasurement {
                                    cell.detailTextLabel?.text = (sensor.State + " " + uom).capitalizedString
                                }
                            }
                            if let thermostat = updatedState as? Thermostat {
                                if let uom = thermostat.UnitOfMeasurement {
                                    cell.detailTextLabel?.text = (thermostat.State + " " + uom).capitalizedString
                                }
                            }
                            cell.imageView?.image = entity.EntityIcon()
                            if let picture = updatedState.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                        }
                }
            case "device_tracker":
                if entity.Attributes["latitude"] != nil && entity.Attributes["longitude"] != nil {
                    let latitude = entity.Attributes["latitude"] as! Double
                    let longitude = entity.Attributes["longitude"] as! Double
                    self.form.last! <<< LocationRow(rowTag) {
                        $0.title = entity.FriendlyName
                        $0.value = CLLocation(latitude: latitude, longitude: longitude)
                        }.cellUpdate { cell, row in
                            if let updatedState = self.updatedStates[rowTag] {
                                cell.detailTextLabel?.text = updatedState.State.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                                cell.imageView?.image = entity.EntityIcon()
                                if let picture = updatedState.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                            }
                    }
                } else {
                    self.form.last! <<< ButtonRow(rowTag) {
                        $0.title = entity.FriendlyName
                        $0.cellStyle = .Value1
                        $0.presentationMode = .Show(controllerProvider: ControllerProvider.Callback {
                            let attributesView = EntityAttributesViewController()
                            attributesView.entity = self.updatedStates[rowTag]
                            return attributesView
                            }, completionCallback: { vc in vc.navigationController?.popViewControllerAnimated(true) })
                        }.cellUpdate { cell, row in
                            if let updatedState = self.updatedStates[rowTag] {
                                cell.detailTextLabel?.text = updatedState.State.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                                if let sensor = updatedState as? Sensor {
                                    cell.detailTextLabel?.text = (sensor.State + " " + sensor.UnitOfMeasurement!).stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                                }
                                cell.imageView?.image = entity.EntityIcon()
                                if let picture = updatedState.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                            }
                    }
                }
            case "input_select":
                self.form.last! <<< PickerInlineRow<String>(rowTag) {
                    $0.title = entity.FriendlyName
                    $0.value = entity.State
                    $0.options = entity.Attributes["options"] as! [String]
                    }.onChange { row -> Void in
                        HomeAssistantAPI.sharedInstance.CallService("input_select", service: "select_option", serviceData: ["entity_id": entity.ID, "option": row.value!])
                    }.cellUpdate { cell, row in
                        if let updatedState = self.updatedStates[rowTag] {
                            cell.imageView?.image = entity.EntityIcon()
                            if let picture = updatedState.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                        }
                }
            case "lock":
                self.form.last! <<< SwitchRow(rowTag) {
                    $0.title = entity.FriendlyName
                    $0.value = (entity.State == "locked") ? true : false
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            HomeAssistantAPI.sharedInstance.CallService("lock", service: "lock", serviceData: ["entity_id": entity.ID])
                        } else {
                            HomeAssistantAPI.sharedInstance.CallService("lock", service: "unlock", serviceData: ["entity_id": entity.ID])
                        }
                    }.cellUpdate { cell, row in
                        if let updatedState = self.updatedStates[rowTag] {
                            cell.imageView?.image = entity.EntityIcon()
                            if let picture = updatedState.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                        }
                }
            case "garage_door":
                self.form.last! <<< SwitchRow(rowTag) {
                    $0.title = entity.FriendlyName
                    $0.value = (entity.State == "open") ? true : false
                    }.onChange { row -> Void in
                        if (row.value == true) {
                            HomeAssistantAPI.sharedInstance.CallService("garage_door", service: "open", serviceData: ["entity_id": entity.ID])
                        } else {
                            HomeAssistantAPI.sharedInstance.CallService("garage_door", service: "close", serviceData: ["entity_id": entity.ID])
                        }
                    }.cellUpdate { cell, row in
                        if let updatedState = self.updatedStates[rowTag] {
                            cell.imageView?.image = entity.EntityIcon()
                            if let picture = updatedState.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                        }
                }
            default:
                print("We don't want this type", entity.Domain)
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GroupViewController.StateChangedSSEEvent(_:)), name:"sse.state_changed", object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func StateChangedSSEEvent(notification: NSNotification){
        if let userInfo = notification.userInfo {
            if let event = Mapper<StateChangedEvent>().map(userInfo) {
                if let newState = event.NewState {
                    self.updatedStates[newState.ID] = newState
                    if newState.Domain == "lock" || newState.Domain == "garage_door" {
                        if let row : SwitchRow = self.form.rowByTag(newState.ID) {
                            row.value = (newState.State == "on") ? true : false
                            row.cell.imageView?.image = newState.EntityIcon()
                            row.updateCell()
                            row.reload()
                        }
                    } else {
                        if let row : ButtonRow = self.form.rowByTag(newState.ID) {
                            row.value = newState.State
                            if let newStateSensor = newState as? Sensor {
                                row.value = newState.State + " " + newStateSensor.UnitOfMeasurement!
                            }
                            row.cell.imageView?.image = newState.EntityIcon()
                            row.updateCell()
                            row.reload()
                        }
                    }
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