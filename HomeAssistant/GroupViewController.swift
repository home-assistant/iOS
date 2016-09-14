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
import RealmSwift

class GroupViewController: FormViewController {
    
    var groupsMap = [String:[String]]()
    
    var GroupID: String = ""
    var Order: Int?
    
    var entities = [String:Entity]()
    
    var sendingEntity : Entity?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if GroupID != "" {
            let group = realm.object(ofType: Group.self, forPrimaryKey: GroupID as AnyObject)
            
            self.form
                +++ Section()
            for entity in group!.Entities {
                switch entity.Domain {
                    //            case "switch", "light", "input_boolean":
                    //                self.form.last! <<< SwitchRow(entity.ID) {
                    //                    $0.title = entity.Name
                    //                    $0.value = (entity.State == "on") ? true : false
                    //                    }.onChange { row -> Void in
                    //                        if (row.value == true) {
                    //                            HomeAssistantAPI.sharedInstance.turnOn(entity.ID)
                    //                        } else {
                    //                            HomeAssistantAPI.sharedInstance.turnOff(entity.ID)
                    //                        }
                    //                    }.cellSetup { cell, row in
                    //                        cell.imageView?.image = entity.EntityIcon
                    //                        if let picture = entity.DownloadedPicture {
                    //                            cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                    //                        }
                //                }
                case "script", "scene":
                    self.form.last! <<< ButtonRow(entity.ID) {
                        $0.title = entity.Name
                        }.onCellSelection { cell, row -> Void in
                            let _ = HomeAssistantAPI.sharedInstance.turnOn(entityId: entity.ID)
                        }.cellUpdate { cell, row in
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                    }
                case "weblink":
                    if let url = URL(string: entity.State) {
                        self.form.last! <<< ButtonRow(entity.ID) {
                            $0.title = entity.Name
                            if url.scheme == "http" || url.scheme == "https" {
                                $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback { return SFSafariViewController(url: url, entersReaderIfAvailable: false) }, completionCallback: { vc in let _ = vc.navigationController?.popViewController(animated: true) })
                            }
                            }.cellUpdate { cell, row in
                                cell.imageView?.image = entity.EntityIcon
                                if let picture = entity.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                            }.onCellSelection { cell, row -> Void in
                                if url.scheme != "http" && url.scheme != "https" {
                                    UIApplication.shared.openURL(url as URL)
                                }
                        }
                    }
                case "switch", "light", "input_boolean", "binary_sensor", "camera", "sensor", "media_player", "thermostat", "sun", "climate", "automation", "fan":
                    self.form.last! <<< ButtonRow(entity.ID) {
                        $0.title = entity.Name
                        $0.cellStyle = .value1
                        $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                            let attributesView = EntityAttributesViewController()
                            attributesView.entityID = entity.ID
                            return attributesView
                            }, completionCallback: {
                                vc in let _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }.cellUpdate { cell, row in
                        cell.detailTextLabel?.text = entity.State.capitalized
                        if let uom = entity.UnitOfMeasurement {
                            cell.detailTextLabel?.text = (entity.State.capitalized + " " + uom)
                        }
                        cell.imageView?.image = entity.EntityIcon
                        if let picture = entity.DownloadedPicture {
                            cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                        }
                    }
                case "device_tracker":
                    if entity.Attributes["latitude"] != nil && entity.Attributes["longitude"] != nil {
                        let latitude = entity.Attributes["latitude"] as! Double
                        let longitude = entity.Attributes["longitude"] as! Double
                        self.form.last! <<< LocationRow(entity.ID) {
                            $0.title = entity.Name
                            $0.value = CLLocation(latitude: latitude, longitude: longitude)
                        }.cellUpdate { cell, row in
                            cell.detailTextLabel?.text = entity.CleanedState
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                        }
                    } else {
                        self.form.last! <<< ButtonRow(entity.ID) {
                            $0.title = entity.Name
                            $0.cellStyle = .value1
                            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                                let attributesView = EntityAttributesViewController()
                                attributesView.entityID = entity.ID
                                return attributesView
                                }, completionCallback: { vc in let _ = vc.navigationController?.popViewController(animated: true) })
                            }.cellUpdate { cell, row in
                                cell.detailTextLabel?.text = entity.CleanedState
                                if let uom = entity.UnitOfMeasurement {
                                    cell.detailTextLabel?.text = (entity.State + " " + uom).replacingOccurrences(of: "_", with: " ").capitalized
                                }
                                cell.imageView?.image = entity.EntityIcon
                                if let picture = entity.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                        }
                    }
                case "input_select":
                    self.form.last! <<< PickerInlineRow<String>(entity.ID) {
                        $0.title = entity.Name
                        $0.value = entity.State
                        $0.options = entity.Attributes["options"] as! [String]
                        }.onChange { row -> Void in
                            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "input_select", service: "select_option", serviceData: ["entity_id": entity.ID as AnyObject, "option": row.value! as AnyObject])
                        }.cellUpdate { cell, row in
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                    }
                case "lock":
                    self.form.last! <<< SwitchRow(entity.ID) {
                        $0.title = entity.Name
                        $0.value = (entity.State == "locked") ? true : false
                        }.onChange { row -> Void in
                            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "lock", service: ((row.value == true) ? "lock" : "unlock"), serviceData: ["entity_id": entity.ID as AnyObject])
                        }.cellUpdate { cell, row in
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                    }
                case "garage_door":
                    self.form.last! <<< SwitchRow(entity.ID) {
                        $0.title = entity.Name
                        $0.value = (entity.State == "open") ? true : false
                        }.onChange { row -> Void in
                            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: "garage_door", service: ((row.value == true) ? "open" : "close"), serviceData: ["entity_id": entity.ID as AnyObject])
                        }.cellUpdate { cell, row in
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                    }
                case "input_slider":
                    self.form.last! <<< SliderRow(entity.ID){
                        $0.title = entity.Name
                        $0.value = Float(entity.State)
                        if let slider = entity as? InputSlider {
                            if let min = slider.Minimum.value {
                                $0.minimumValue = min
                            }
                            if let max = slider.Maximum.value {
                                $0.maximumValue = max
                            }
                            if let steps = slider.Step.value {
                                $0.steps = UInt(steps)
                            }
                        }
                        
                    }.onChange { row -> Void in
                        if let slider = entity as? InputSlider {
                            slider.SelectValue(row.value!)
                        }
                    }.cellUpdate { cell, row in
//                        if let uom = entity.UnitOfMeasurement {
//                            cell.detailTextLabel?.text = (entity.State.capitalized + " " + uom)
//                        }
                        row.displayValueFor = { (pos: Float?) in
                            print(pos)
                            return (entity.State.capitalized + " " + entity.UnitOfMeasurement!)
                        }
                    }
                default:
                    print("There is no row type defined for \(entity.Domain) so we are skipping it")
                }
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(GroupViewController.StateChangedSSEEvent(_:)), name:NSNotification.Name(rawValue: "sse.state_changed"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func StateChangedSSEEvent(_ notification: NSNotification){
        if let userInfo = (notification as NSNotification).userInfo {
            if let event = Mapper<StateChangedEvent>().map(userInfo) {
                if let newState = event.NewState {
                    if newState.Domain == "lock" || newState.Domain == "garage_door" {
                        if let row : SwitchRow = self.form.rowByTag(newState.ID) {
                            row.value = (newState.State == "on") ? true : false
                            row.cell.imageView?.image = newState.EntityIcon
                            row.updateCell()
                            row.reload()
                        }
                    } else {
                        if let row : ButtonRow = self.form.rowByTag(newState.ID) {
                            row.value = newState.State
                            if let uom = newState.UnitOfMeasurement {
                                row.value = newState.State + " " + uom
                            }
                            row.cell.imageView?.image = newState.EntityIcon
                            row.updateCell()
                            row.reload()
                        }
                    }
                }
            }
        }
    }
    
    func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "ShowEntityAttributes" {
            let entityAttributesViewController = segue.destination as! EntityAttributesViewController
            entityAttributesViewController.entityID = sendingEntity!.ID
        }
    }
    
    
}
