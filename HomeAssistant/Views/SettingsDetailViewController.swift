//
//  SecondViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import PermissionScope
import PromiseKit
import Crashlytics

class SettingsDetailViewController: FormViewController {

    var detailGroup: String = "display"

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        switch detailGroup {
        case "general":
            self.title = L10n.SettingsDetails.General.title
            self.form
                +++ Section()
                <<< SwitchRow("openInChrome") {
                    $0.title = L10n.SettingsDetails.General.Chrome.title
                    $0.value = prefs.bool(forKey: "openInChrome")
                    }.onChange { row in
                        prefs.setValue(row.value, forKey: "openInChrome")
                        prefs.synchronize()
            }
            //                <<< SwitchRow("allowAllGroups") {
            //                    $0.title = "Show all groups"
            //                    $0.value = prefs.bool(forKey: "allowAllGroups")
            //                    }.onChange { row in
            //                        prefs.setValue(row.value, forKey: "allowAllGroups")
            //                        prefs.synchronize()
        //                }
        case "location":
            self.title = L10n.SettingsDetails.Location.title
            self.form
                +++ Section(header: L10n.SettingsDetails.Location.Notifications.header, footer: "")
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.Enter.title
                    $0.value = prefs.bool(forKey: "enterNotifications")
                }.onChange({ (row) in
                    if let val = row.value {
                        prefs.set(val, forKey: "enterNotifications")
                    }
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.Exit.title
                    $0.value = prefs.bool(forKey: "exitNotifications")
                }.onChange({ (row) in
                    if let val = row.value {
                        prefs.set(val, forKey: "exitNotifications")
                    }
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.LocationChange.title
                    $0.value = prefs.bool(forKey: "significantLocationChangeNotifications")
                }.onChange({ (row) in
                    if let val = row.value {
                        prefs.set(val, forKey: "significantLocationChangeNotifications")
                    }
                })
            if let cachedEntities = HomeAssistantAPI.sharedInstance.cachedEntities {
                if let zoneEntities: [Zone] = cachedEntities.filter({ (entity) -> Bool in
                    return entity.Domain == "zone"
                }) as? [Zone] {
                    for zone in zoneEntities {
                        self.form
                            +++ Section(header: zone.Name, footer: "") {
                                $0.tag = zone.ID
                            }
                            <<< SwitchRow {
                                $0.title = L10n.SettingsDetails.Location.Zones.EnterExitTracked.title
                                $0.value = zone.TrackingEnabled
                                $0.disabled = Condition(booleanLiteral: true)
                            }
                            <<< LocationRow {
                                $0.title = L10n.SettingsDetails.Location.Zones.Location.title
                                $0.value = zone.location()
                            }
                            <<< LabelRow {
                                $0.title = L10n.SettingsDetails.Location.Zones.Radius.title
                                $0.value = "\(Int(zone.Radius)) m"
                        }
                    }
                    if zoneEntities.count > 0 {
                        self.form
                            +++ Section(header: "",
                                        // swiftlint:disable:next line_length
                                        footer: L10n.SettingsDetails.Location.Zones.footer)
                    }
                }
            }

        case "notifications":
            self.title = "Notification Settings"
            self.form
                +++ Section(header: L10n.SettingsDetails.Notifications.PushIdSection.header,
                            // swiftlint:disable:next line_length
                    footer: L10n.SettingsDetails.Notifications.PushIdSection.footer)
                <<< TextAreaRow {
                    $0.placeholder = L10n.SettingsDetails.Notifications.PushIdSection.placeholder
                    if let pushID = prefs.string(forKey: "pushID") {
                        $0.value = pushID
                    } else {
                        $0.value = L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
                    }
                    $0.disabled = true
                    $0.textAreaHeight = TextAreaHeight.dynamic(initialTextViewHeight: 40)
                    }.onCellSelection { _, row in
                        let activityViewController = UIActivityViewController(activityItems: [row.value! as String],
                                                                              applicationActivities: nil)
                        self.present(activityViewController, animated: true, completion: {})
                }

                +++ Section(header: "",
                            // swiftlint:disable:next line_length
                    footer: L10n.SettingsDetails.Notifications.UpdateSection.footer)
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.UpdateSection.Button.title
                    }.onCellSelection {_, _ in
                        HomeAssistantAPI.sharedInstance.setupPush()
                        // swiftlint:disable:next line_length
                        let alert = UIAlertController(title: L10n.SettingsDetails.Notifications.UpdateSection.UpdatedAlert.title,
                                                      // swiftlint:disable:next line_length
                                                      message: L10n.SettingsDetails.Notifications.UpdateSection.UpdatedAlert.message,
                                                      preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default,
                                                      handler: nil))
                        self.present(alert, animated: true, completion: nil)
                }

                +++ Section(header: "", footer: L10n.SettingsDetails.Notifications.SoundsSection.footer)
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.SoundsSection.Button.title
                    }.onCellSelection {_, _ in
                        let moved = movePushNotificationSounds()
                        // swiftlint:disable:next line_length
                        let alert = UIAlertController(title: L10n.SettingsDetails.Notifications.SoundsSection.ImportedAlert.title,
                                                      // swiftlint:disable:next line_length
                                                      message: L10n.SettingsDetails.Notifications.SoundsSection.ImportedAlert.message(moved),
                                                      preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                      style: UIAlertActionStyle.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
            }

            //                <<< ButtonRow {
            //                    $0.title = "Import system sounds"
            //                }.onCellSelection {_,_ in
            //                    let list = getSoundList()
            //                    print("system sounds list", list)
            //                    for sound in list {
            //                        copyFileToDirectory(sound)
            //                    }
        //                }
        default:
            print("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
