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

    var groupsMap = [String: [String]]()

    var GroupID: String = ""
    var Order: Int?

    var entities = [String: Entity]()

    var sendingEntity: Entity?

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {

        super.viewDidLoad()

        if GroupID != "" {
            let group = realm.object(ofType: Group.self, forPrimaryKey: GroupID as AnyObject)

            self.form
                +++ Section()
            for entity in group!.Entities {
                switch entity.Domain {
                case "script", "scene":
                    self.form.last! <<< ButtonRow(entity.ID) {
                        $0.title = entity.Name
                        }.onCellSelection { _, _ -> Void in
                            _ = HomeAssistantAPI.sharedInstance.turnOn(entityId: entity.ID)
                        }.cellUpdate { cell, _ in
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
                                $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                                    return SFSafariViewController(url: url, entersReaderIfAvailable: false)
                                    }, onDismiss: { vc in
                                        _ = vc.navigationController?.popViewController(animated: true)
                                })
                            }
                            }.cellUpdate { cell, _ in
                                cell.imageView?.image = entity.EntityIcon
                                if let picture = entity.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                            }.onCellSelection { _, _ -> Void in
                                if url.scheme != "http" && url.scheme != "https" {
                                    UIApplication.shared.openURL(url as URL)
                                }
                        }
                    }
                case "switch", "light", "input_boolean", "binary_sensor", "camera", "sensor", "media_player",
                     "thermostat", "sun", "climate", "automation", "fan":
                    self.form.last! <<< ButtonRow(entity.ID) {
                        $0.title = entity.Name
                        $0.cellStyle = .value1
                        $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                            let attributesView = EntityAttributesViewController()
                            attributesView.entityID = entity.ID
                            return attributesView
                            }, onDismiss: {
                                vc in _ = vc.navigationController?.popViewController(animated: true)
                        })
                        }.cellUpdate { cell, _ in
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
                    if let dtracker = realm.object(ofType: DeviceTracker.self, forPrimaryKey: entity.ID) {
                        if dtracker.Latitude.value != nil && dtracker.Longitude.value != nil {
                            self.form.last! <<< LocationRow(entity.ID) {
                                $0.title = entity.Name
                                $0.value = dtracker.location()
                                }.cellUpdate { cell, _ in
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
                                    }, onDismiss: {
                                        vc in _ = vc.navigationController?.popViewController(animated: true)
                                })
                                }.cellUpdate { cell, _ in
                                    cell.detailTextLabel?.text = entity.CleanedState
                                    if let uom = entity.UnitOfMeasurement {
                                        let combinedString = entity.State + " " + uom
                                        let withReplacements = combinedString.replacingOccurrences(of: "_", with: " ")
                                        cell.detailTextLabel?.text = withReplacements.capitalized
                                    }
                                    cell.imageView?.image = entity.EntityIcon
                                    if let picture = entity.DownloadedPicture {
                                        cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                    }
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
                            }, onDismiss: { vc in _ = vc.navigationController?.popViewController(animated: true) })
                            }.cellUpdate { cell, _ in
                                cell.detailTextLabel?.text = entity.CleanedState
                                if let uom = entity.UnitOfMeasurement {
                                    let combinedString = entity.State + " " + uom
                                    let withReplacements = combinedString.replacingOccurrences(of: "_", with: " ")
                                    cell.detailTextLabel?.text = withReplacements.capitalized
                                }
                                cell.imageView?.image = entity.EntityIcon
                                if let picture = entity.DownloadedPicture {
                                    cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                                }
                        }
                    }
                    //                case "input_select":
                    //                    self.form.last! <<< PickerInlineRow<String>(entity.ID) {
                    //                        $0.title = entity.Name
                    //                        $0.value = entity.State
                    //                        $0.options = entity.Attributes["options"] as! [String]
                    //                    }.onChange { row -> Void in
                    // swiftlint:disable:next line_length
                    //                        _ = HomeAssistantAPI.sharedInstance.CallService(domain: "input_select", service: "select_option", serviceData: ["entity_id": entity.ID as AnyObject, "option": row.value! as AnyObject])
                    //                    }.cellUpdate { cell, row in
                    //                        cell.imageView?.image = entity.EntityIcon
                    //                        if let picture = entity.DownloadedPicture {
                    // swiftlint:disable:next line_length
                    //                            cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                    //                        }
                //                    }
                case "lock":
                    self.form.last! <<< SwitchRow(entity.ID) {
                        $0.title = entity.Name
                        $0.value = (entity.State == "locked") ? true : false
                        }.onChange { row -> Void in
                            let whichService = (row.value == true) ? "lock" : "unlock"
                            _ = HomeAssistantAPI.sharedInstance.CallService(domain: "lock", service: whichService,
                                                                            serviceData: [
                                                                                "entity_id": entity.ID as AnyObject
                                ])
                        }.cellUpdate { cell, _ in
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
                            let whichService = (row.value == true) ? "open" : "close"
                            _ = HomeAssistantAPI.sharedInstance.CallService(domain: "garage_door",
                                                                            service: whichService,
                                                                            serviceData: [
                                                                                "entity_id": entity.ID as AnyObject
                                ])
                        }.cellUpdate { cell, _ in
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                    }
                case "cover":
                    self.form.last! <<< SegmentedRow<String>(entity.ID) {
                        $0.title = entity.Name
                        $0.options = ["Open", "Stop", "Close"]
                        $0.value = (entity.State == "closed") ? "Close" : "Open"
                        }.onChange { row -> Void in
                            let whichService = row.value!.lowercased() + "_cover"
                            let _ = HomeAssistantAPI.sharedInstance.CallService(domain: entity.Domain,
                                                                                service: whichService,
                                                                                serviceData: [
                                                                                    "entity_id": entity.ID as AnyObject
                                ])
                        }.cellUpdate { cell, _ in
                            cell.imageView?.image = entity.EntityIcon
                            if let picture = entity.DownloadedPicture {
                                cell.imageView?.image = picture.scaledToSize(CGSize(width: 30, height: 30))
                            }
                    }
                case "input_slider":
                    self.form.last! <<< SliderRow(entity.ID) {
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
                        }.cellUpdate { _, row in
                            row.displayValueFor = { (_) in
                                if let uom = entity.UnitOfMeasurement {
                                    return (entity.State.capitalized + " " + uom)
                                } else {
                                    return entity.State.capitalized
                                }
                            }
                    }
                default:
                    print("There is no row type defined for \(entity.Domain) so we are skipping it")
                }
            }
        }

    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "ShowEntityAttributes" {
            if let destination = segue.destination as? EntityAttributesViewController {
                destination.entityID = sendingEntity!.ID
            }
        }
    }

}
