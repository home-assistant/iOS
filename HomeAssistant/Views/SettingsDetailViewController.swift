//
//  SecondViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import Crashlytics
import Shared
import Intents
import IntentsUI
import PromiseKit

class SettingsDetailViewController: FormViewController {

    var detailGroup: String = "display"

    var doneButton: Bool = false

    var voiceShortcutManager: Any?

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        if doneButton {
            let closeSelector = #selector(SettingsDetailViewController.closeSettingsDetailView(_:))
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                             action: closeSelector)
            self.navigationItem.setRightBarButton(doneButton, animated: true)
        }

        if #available(iOS 12.0, *) {
            voiceShortcutManager = VoiceShortcutsManager.init()
        }

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
        case "location":
            self.title = L10n.SettingsDetails.Location.title
            self.form
                +++ Section(header: L10n.SettingsDetails.Location.Updates.header,
                            footer: L10n.SettingsDetails.Location.Updates.footer)
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Zone.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnZone")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnZone")
                        }
                    })
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Background.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnBackgroundFetch")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnBackgroundFetch")
                        }
                    })
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Significant.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnSignificant")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnSignificant")
                        }
                    })
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Notification.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnNotification")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnNotification")
                        }
                    })

            let realm = Current.realm()
            let zoneEntities = realm.objects(RLMZone.self).map { $0 }
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
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconUuid.title
                        $0.value = zone.BeaconUUID
                        $0.hidden = Condition(booleanLiteral: (zone.BeaconUUID == nil))
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconMajor.title
                        if let major = zone.BeaconMajor.value {
                            $0.value = String(describing: major)
                        } else {
                            $0.value = L10n.SettingsDetails.Location.Zones.Beacon.PropNotSet.value
                        }
                        $0.hidden = Condition(booleanLiteral: (zone.BeaconMajor.value == nil))
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconMinor.title
                        if let minor = zone.BeaconMinor.value {
                            $0.value = String(describing: minor)
                        } else {
                            $0.value = L10n.SettingsDetails.Location.Zones.Beacon.PropNotSet.value
                        }
                        $0.hidden = Condition(booleanLiteral: (zone.BeaconMinor.value == nil))
                }
            }
            if zoneEntities.count > 0 {
                self.form
                    +++ Section(header: "", footer: L10n.SettingsDetails.Location.Zones.footer)
            }

        case "notifications":
            self.title = L10n.SettingsDetails.Notifications.title
            self.form
                +++ Section()
                <<< SwitchRow("confirmBeforeOpeningUrl") {
                    $0.title = L10n.SettingsDetails.Notifications.PromptToOpenUrls.title
                    $0.value = prefs.bool(forKey: "confirmBeforeOpeningUrl")
                }.onChange { row in
                    prefs.setValue(row.value, forKey: "confirmBeforeOpeningUrl")
                    prefs.synchronize()
                }
                +++ Section(header: L10n.SettingsDetails.Notifications.PushIdSection.header,
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

                +++ Section(header: "", footer: L10n.SettingsDetails.Notifications.UpdateSection.footer)
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.UpdateSection.Button.title
                }.onCellSelection {_, _ in
                    HomeAssistantAPI.authenticatedAPI()?.setupPush()
                    let title = L10n.SettingsDetails.Notifications.UpdateSection.UpdatedAlert.title
                    let message = L10n.SettingsDetails.Notifications.UpdateSection.UpdatedAlert.message
                    let alert = UIAlertController(title: title,
                                                  message: message,
                                                  preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
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
                                                      preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                      style: UIAlertAction.Style.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                }

                +++ Section(header: "", footer: "")
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.BadgeSection.Button.title
                }.onCellSelection {_, _ in
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    // swiftlint:disable:next line_length
                    let alert = UIAlertController(title: L10n.SettingsDetails.Notifications.BadgeSection.ResetAlert.title,
                                                  // swiftlint:disable:next line_length
                                                  message: L10n.SettingsDetails.Notifications.BadgeSection.ResetAlert.message,
                                                  preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                  style: UIAlertAction.Style.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }

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
                    $0.title = L10n.SettingsDetails.Location.Notifications.BeaconEnter.title
                    $0.value = prefs.bool(forKey: "beaconEnterNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "beaconEnterNotifications")
                        }
                    })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.BeaconExit.title
                    $0.value = prefs.bool(forKey: "beaconExitNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "beaconExitNotifications")
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
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.BackgroundFetch.title
                    $0.value = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "backgroundFetchLocationChangeNotifications")
                        }
                    })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.PushNotification.title
                    $0.value = prefs.bool(forKey: "pushLocationRequestNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "pushLocationRequestNotifications")
                        }
                    })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.UrlScheme.title
                    $0.value = prefs.bool(forKey: "urlSchemeLocationRequestNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "urlSchemeLocationRequestNotifications")
                        }
                    })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Notifications.Visit.title
                    $0.value = prefs.bool(forKey: "visitLocationRequestNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "visitLocationRequestNotifications")
                        }
                    })

        case "siri":
            INPreferences.requestSiriAuthorization { (status) in
                print("Siri auth status", status.rawValue)
            }

            var entityIDs: [String] = []

            _ = HomeAssistantAPI.authenticatedAPI()?.GetStates().done { entities in
                for entity in entities {
                    entityIDs.append(entity.ID)
                }
            }

            self.title = L10n.SettingsDetails.Siri.title
            if #available(iOS 12.0, *) {
                let realm = Current.realm()
                let shortcuts = realm.objects(SiriShortcut.self).map { $0 }
                if shortcuts.count > 0 {
                    self.form
                        +++ Section(header: "Existing Shortcuts", footer: "")
                }
                for shortcut in shortcuts {
                self.form.last!
                    <<< ButtonRow {
                        $0.cellStyle = .subtitle
                        $0.title = shortcut.InvocationPhrase
                        $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                            if let identifier = shortcut.Identifier,
                                let shortcutManager = self.voiceShortcutManager as? VoiceShortcutsManager,
                                let shortcut = shortcutManager.voiceShortcut(for: identifier) {
                                let viewController = INUIEditVoiceShortcutViewController(voiceShortcut: shortcut)
                                viewController.delegate = self
                                return viewController
                            }
                            return UIViewController()
                        }, onDismiss: { vc in
                            _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }.cellUpdate({ cell, _ in
                        cell.detailTextLabel?.text = shortcut.Data
                    })
                }

                self.form
                    +++ Section(header: "Generic Shortcuts", footer: "")
                    <<< ButtonRow {
                        $0.title = "Send Location"
                        $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                            if let shortcut = INShortcut(intent: SendLocationIntent()) {
                                let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
                                viewController.delegate = self
                                return viewController
                            }
                            return UIViewController()
                        }, onDismiss: { vc in
                            _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }

                    self.form +++ Section(header: "Services", footer: "")

                _ = HomeAssistantAPI.authenticatedAPIPromise.then { api in
                    api.GetServices()
                }.done { serviceResp in
                    for domainContainer in serviceResp.sorted(by: { (a, b) -> Bool in
                        return a.Domain < b.Domain
                    }) {
                        for service in domainContainer.Services.sorted(by: { (a, b) -> Bool in
                            return a.key < b.key
                        }) {

                            self.form.last! <<< ButtonRow {
                                $0.title = domainContainer.Domain + "." + service.key
                                $0.cellStyle = .subtitle
                                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                                    let siriConfigurator = SiriShortcutServiceConfigurator()
                                    siriConfigurator.domain = domainContainer.Domain
                                    siriConfigurator.serviceName = service.key
                                    siriConfigurator.serviceData = service.value
                                    siriConfigurator.entityIDs = entityIDs
                                    return siriConfigurator
                                }, onDismiss: { vc in
                                    _ = vc.navigationController?.popViewController(animated: true)
                                })
                            }.cellUpdate({ cell, _ in
                                cell.detailTextLabel?.text = service.value.Description
                            })
                        }
                    }
                }

            }

        default:
            print("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
}

@available (iOS 12, *)
extension SettingsDetailViewController: INUIAddVoiceShortcutViewControllerDelegate {

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                        didFinishWith voiceShortcut: INVoiceShortcut?,
                                        error: Error?) {
        if let error = error {
            print("error adding voice shortcut:\(error.localizedDescription)")
            return
        }
        print("UPDATE SHORTCUTS 3")
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - INUIEditVoiceShortcutViewControllerDelegate

@available (iOS 12, *)
extension SettingsDetailViewController: INUIEditVoiceShortcutViewControllerDelegate {

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didUpdate voiceShortcut: INVoiceShortcut?,
                                         error: Error?) {
        if let error = error {
            print("error adding voice shortcut:\(error.localizedDescription)")
            return
        }
        print("UPDATE SHORTCUTS HERE 1")
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        print("UPDATE SHORTCUTS HERE 2")
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        dismiss(animated: true, completion: nil)
    }
}
