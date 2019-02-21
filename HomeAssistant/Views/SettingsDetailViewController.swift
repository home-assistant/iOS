//
//  SecondViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import Shared
import Intents
import IntentsUI
import PromiseKit
import RealmSwift
import UserNotifications
import Communicator
import CleanroomLogger

// swiftlint:disable:next type_body_length
class SettingsDetailViewController: FormViewController {

    var detailGroup: String = "display"

    var doneButton: Bool = false

    private let realm = Current.realm()

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

                +++ Section()
                <<< PushRow<AppIcon>("appIcon") {
                        $0.title = "Icon"
                        $0.options = AppIcon.allCases
                        $0.value = AppIcon.Release
                        if let altIconName = UIApplication.shared.alternateIconName,
                            let icon = AppIcon(rawValue: altIconName) {
                            $0.value = icon
                        }
                        $0.selectorTitle = "App Icon"
                    }.onPresent { _, to in
                        to.selectableRowCellUpdate = { (cell, row) in
                            cell.height = { return 72 }
                            cell.imageView?.layer.masksToBounds = true
                            cell.imageView?.layer.cornerRadius = 12.63
                            guard let newIcon = row.selectableValue else { return }
                            cell.imageView?.image = UIImage(named: newIcon.rawValue)

                            cell.textLabel?.text = newIcon.title
                        }
                    }.onChange { row in
                        guard let newAppIconName = row.value else { return }
                        guard UIApplication.shared.alternateIconName != newAppIconName.rawValue else { return }

                        UIApplication.shared.setAlternateIconName(newAppIconName.rawValue)
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
                        $0.value = L10n.SettingsDetails.Location.Zones.Radius.label(Int(zone.Radius))
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

            var notificationSettings: UNNotificationSettings?

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                notificationSettings = settings
            }

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
                    $0.tag = "pushID"
                    $0.placeholder = L10n.SettingsDetails.Notifications.PushIdSection.placeholder
                    if let pushID = prefs.string(forKey: "pushID") {
                        $0.value = pushID
                    } else {
                        $0.value = L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
                    }
                    $0.disabled = true
                    $0.textAreaHeight = TextAreaHeight.dynamic(initialTextViewHeight: 40)
                }.cellSetup { cell, _ in
                    cell.textView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                              action: #selector(self.tapPushID(_:))))
                }

                let objs = realm.objects(NotificationCategory.self)
                let categories = objs.sorted(byKeyPath: "Identifier")

                let mvOpts: MultivaluedOptions = [.Insert, .Delete, .Reorder]

                self.form
                    +++ MultivaluedSection(multivaluedOptions: mvOpts,
                                           header: L10n.SettingsDetails.Notifications.Categories.header,
                                           footer: "") { section in
                        section.multivaluedRowToInsertAt = { index in
                            return self.getNotificationCategoryRow(nil, notificationSettings)
                        }

                        for category in categories {
                            section <<< getNotificationCategoryRow(category, notificationSettings)
                        }
                }

                +++ Section()
                <<< ButtonRow {
                        $0.title = L10n.SettingsDetails.Notifications.ImportLegacySettings.Button.title
                    }.onCellSelection {_, _ in
                        MigratePushSettingsToLocal()
                        // swiftlint:disable:next line_length
                        let alert = UIAlertController(title: L10n.SettingsDetails.Notifications.ImportLegacySettings.Alert.title,
                                                      // swiftlint:disable:next line_length
                                                      message: L10n.SettingsDetails.Notifications.ImportLegacySettings.Alert.message,
                                                      preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                      style: UIAlertAction.Style.default, handler: nil))
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
                    $0.title = L10n.SettingsDetails.Location.Notifications.XCallbackUrl.title
                    $0.value = prefs.bool(forKey: "xCallbackURLLocationRequestNotifications")
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "xCallbackURLLocationRequestNotifications")
                        }
                    })

        case "watchSettings":
            self.title = L10n.SettingsDetails.Watch.title

            let sends = Communicator.shared.currentWatchState.numberOfComplicationInfoTransfersAvailable.description

            self.form
                +++ Section {
                    $0.tag = "watch_data"
                }
                <<< LabelRow {
                    $0.tag = "remaining_complication_sends"
                    $0.title = L10n.SettingsDetails.Watch.RemainingSends.title
                    $0.value = sends
                }

                <<< ButtonRow {
                        $0.title = L10n.SettingsDetails.Watch.SendNow.title
                    }.onCellSelection { _, _ in

                        var complications: [String: Any] = [String: Any]()

                        for config in self.realm.objects(WatchComplication.self) {
                            Log.verbose?.message("Config \(config)")
                            Log.verbose?.message("Running toJSON! \(config.toJSON())")
                            complications[config.Family.rawValue] = config.toJSON()
                        }

                        Log.verbose?.message("Sending \(complications)")

                        let complicationInfo = ComplicationInfo(content: complications)

                        do {
                            try Communicator.shared.transfer(complicationInfo: complicationInfo)
                        } catch let error as NSError {
                            Log.error?.message("Error transferring complication info: \(error)")
                        }

                        if let remainingRow = self.form.rowBy(tag: "remaining_complication_sends") as? LabelRow {
                            // swiftlint:disable:next line_length
                            remainingRow.value = Communicator.shared.currentWatchState.numberOfComplicationInfoTransfersAvailable.description
                            self.tableView.reloadData()
                        }
                    }

            let existingComplications = Current.realm().objects(WatchComplication.self)

            for group in ComplicationGroup.allCases {
                let members = group.members
                var header = group.name
                if members.count == 1 {
                    header = ""
                }
                self.form +++ Section(header: header, footer: group.description)

                for member in members {

                    var config = existingComplications.filter(NSPredicate(format: "rawFamily == %@",
                                                                          member.rawValue)).first

                    if config == nil {
                        let newConfig = WatchComplication()
                        newConfig.Family = member
                        config = newConfig
                    }

                    self.form.last!
                        <<< ButtonRow {
                            $0.cellStyle = .subtitle
                            $0.title = member.shortName
                            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                                    return WatchComplicationConfigurator(config)
                                }, onDismiss: { vc in
                                    _ = vc.navigationController?.popViewController(animated: true)
                            })
                            }.cellUpdate({ (cell, _) in
                                cell.detailTextLabel?.text = member.description
                                cell.detailTextLabel?.numberOfLines = 0
                                cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                            })
                }

            }

        case "siri":
            self.title = L10n.SettingsDetails.Siri.title
            if #available(iOS 12.0, *) {
                INPreferences.requestSiriAuthorization { (status) in
                    Log.verbose?.message("Siri auth status \(status.rawValue)")
                }

                var entityIDs: [String] = []

                _ = HomeAssistantAPI.authenticatedAPI()?.GetStates().done { entities in
                    for entity in entities {
                        entityIDs.append(entity.ID)
                    }
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

                    <<< ButtonRow {
                        $0.title = "Fire Event"
                        $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                            return ShortcutEventConfigurator()
                            }, onDismiss: { vc in
                                _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }

                    <<< ButtonRow {
                        $0.title = "Get Camera Image"
                        $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                            if let shortcut = INShortcut(intent: GetCameraImageIntent()) {
                                let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
                                viewController.delegate = self
                                return viewController
                            }
                            return UIViewController()
                            }, onDismiss: { vc in
                                _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }

                    <<< ButtonRow {
                        $0.title = "Render Template"
                        $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                            if let shortcut = INShortcut(intent: RenderTemplateIntent()) {
                                let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
                                viewController.delegate = self
                                return viewController
                            }
                            return UIViewController()
                            }, onDismiss: { vc in
                                _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }

                _ = HomeAssistantAPI.authenticatedAPIPromise.then { api in
                    api.GetServices()
                }.done { serviceResp in
                    let servicesSection = Section(header: "Services", footer: "")
                    for domainContainer in serviceResp.sorted(by: { (a, b) -> Bool in
                        return a.Domain < b.Domain
                    }) {
                        for service in domainContainer.Services.sorted(by: { (a, b) -> Bool in
                            return a.key < b.key
                        }) {

                            let serviceRow = ButtonRow {
                                $0.title = domainContainer.Domain + "." + service.key
                                $0.cellStyle = .subtitle
                                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                                    let siriConfigurator = ShortcutServiceConfigurator()
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
                                cell.detailTextLabel?.numberOfLines = 0
                                cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                            })

                            servicesSection.append(serviceRow)
                        }
                    }
                    self.form.append(servicesSection)
                    self.tableView.reloadData()
                }

                INVoiceShortcutCenter.shared.getAllVoiceShortcuts { (voiceShortcutsFromCenter, error) in
                    DispatchQueue.main.async {
                        guard let voiceShortcutsFromCenter = voiceShortcutsFromCenter else {
                            if let error = error {
                                Log.error?.message("Failed to fetch voice shortcuts with error: \(error)")
                            }
                            return
                        }

                        guard voiceShortcutsFromCenter.count > 0 else { return }

                        let existingSection = Section(header: "Existing Shortcuts", footer: "") {
                            $0.tag = "existing_shortcuts"
                        }

                        let sectionRows = voiceShortcutsFromCenter.map({ (shortcut: INVoiceShortcut) in
                            return ButtonRow {
                                $0.tag = shortcut.identifier.uuidString
                                $0.title = shortcut.invocationPhrase
                                $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                                    let viewController = INUIEditVoiceShortcutViewController(voiceShortcut: shortcut)
                                    viewController.delegate = self
                                    return viewController
                                    }, onDismiss: { vc in
                                        _ = vc.navigationController?.popViewController(animated: true)
                                })
                            }
                        })

                        existingSection.append(contentsOf: sectionRows)
                        self.form.insert(existingSection, at: 0)
                        self.tableView.reloadData()
                    }
                }

            }

        case "actions":
            let objs = realm.objects(Action.self)
            let actions = objs.sorted(byKeyPath: "Position")

            self.form
                +++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete, .Reorder],
                                       header: "",
                                       footer: "Actions are used in the Today widget and Apple Watch app") { section in
                                        section.multivaluedRowToInsertAt = { index in
                                            return self.getActionRow(nil)
                                        }

                                        for action in actions {
                                            section <<< getActionRow(action)
                                        }
            }
        default:
            Log.warning?.message("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)

        let deletedIDs = rows.compactMap { $0.tag }

        let realm = Realm.live()
        // swiftlint:disable:next force_try
        try! realm.write {
            realm.delete(realm.objects(Action.self).filter("ID IN %@", deletedIDs))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    func getNotificationCategoryRow(_ category: NotificationCategory?, _ settings: UNNotificationSettings?) ->
        ButtonRowWithPresent<NotificationCategoryConfigurator> {
        var identifier = "new_category_"+UUID().uuidString
        var title = L10n.SettingsDetails.Notifications.NewCategory.title

        if let category = category {
            identifier = category.Identifier
            title = category.Name
        }

        return ButtonRowWithPresent<NotificationCategoryConfigurator> {
            $0.tag = identifier
            $0.title = title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                return NotificationCategoryConfigurator(category: category, settings: settings)
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? NotificationCategoryConfigurator {
                    if vc.shouldSave == false {
                        Log.verbose?.message("Not saving category to DB and returning early!")
                        return
                    }

                    vc.row.title = vc.category.Name
                    vc.row.updateCell()

                    Log.verbose?.message("Saving category! \(vc.category)")

                    // swiftlint:disable:next force_try
                    try! self.realm.write {
                        self.realm.add(vc.category, update: true)
                    }
                }

                ProvideNotificationCategoriesToSystem()
            })
        }
    }

    @objc func tapPushID(_ sender: Any) {
        if let row = self.form.rowBy(tag: "pushID") as? TextAreaRow, let rowValue = row.value {
            let activityViewController = UIActivityViewController(activityItems: [rowValue],
                                                                  applicationActivities: nil)
            self.present(activityViewController, animated: true, completion: {})
            if let popOver = activityViewController.popoverPresentationController {
                popOver.sourceView = self.view
            }
        }
    }

    func getActionRow(_ inputAction: Action?) -> ButtonRowWithPresent<ActionConfigurator> {
            var identifier = UUID().uuidString
            var title = "New Action"
            let action = inputAction

            if let passedAction = inputAction {
                identifier = passedAction.ID
                title = passedAction.Name
            }

            return ButtonRowWithPresent<ActionConfigurator> {
                $0.tag = identifier
                $0.title = title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    return ActionConfigurator(action: action)
                    }, onDismiss: { vc in
                        _ = vc.navigationController?.popViewController(animated: true)

                        if let vc = vc as? ActionConfigurator {
                            if vc.shouldSave == false {
                                Log.verbose?.message("Not saving action to DB and returning early!")
                                return
                            }

                            vc.row.title = vc.action.Name
                            vc.row.updateCell()

                            Log.verbose?.message("Saving action! \(vc.action)")

                            let realm = Current.realm()

                            do {
                                try realm.write {
                                    realm.add(vc.action, update: true)
                                }
                            } catch let error as NSError {
                                Log.error?.message("Error while saving to Realm!: \(error)")
                            }

                            let data = Array(realm.objects(Action.self))

                            let message = GuaranteedMessage(identifier: "actions", content: ["data": data.toJSON()])

                            Log.verbose?.message("Sending message \(message)")

                            do {
                                try Communicator.shared.send(guaranteedMessage: message)
                            } catch let error as NSError {
                                Log.error?.message("Sending actions failed: \(error)")
                            }
                        }
                })
            }
    }
}

enum AppIcon: String, CaseIterable {
    case Release = "release"
    case Beta = "beta"
    case Dev = "dev"
    case Black = "black"
    case Blue = "blue"
    case Green = "green"
    case Orange = "orange"
    case Purple = "purple"
    case Red = "red"
    case White = "white"
    case OldRelease = "old-release"
    case OldBeta = "old-beta"
    case OldDev = "old-dev"

    var title: String {
        switch self {
        case .Beta:
            return "Beta"
        case .Dev:
            return "Dev"
        case .Release:
            return "Release"
        case .Black:
            return "Black"
        case .Blue:
            return "Blue"
        case .Green:
            return "Green"
        case .Orange:
            return "Orange"
        case .Purple:
            return "Purple"
        case .Red:
            return "Red"
        case .White:
            return "White"
        case .OldRelease:
            return "Old Release"
        case .OldBeta:
            return "Old Beta"
        case .OldDev:
            return "Old Dev"
        }
    }
}

@available (iOS 12, *)
extension SettingsDetailViewController: INUIAddVoiceShortcutViewControllerDelegate {

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                        didFinishWith voiceShortcut: INVoiceShortcut?,
                                        error: Error?) {
        if let error = error as NSError? {
            Log.error?.message("Error adding voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }

        if let voiceShortcut = voiceShortcut {
            Log.verbose?.message("Shortcut with ID \(voiceShortcut.identifier.uuidString) added")

            if let existingSection = self.form.sectionBy(tag: "existing_shortcuts") {
                let newShortcut = ButtonRow {
                    $0.tag = voiceShortcut.identifier.uuidString
                    $0.title = voiceShortcut.invocationPhrase
                    $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                        let viewController = INUIEditVoiceShortcutViewController(voiceShortcut: voiceShortcut)
                        viewController.delegate = self
                        return viewController
                        }, onDismiss: { vc in
                            _ = vc.navigationController?.popViewController(animated: true)
                    })
                }

                existingSection.append(newShortcut)

                self.tableView.reloadData()
            }
        }

        controller.dismiss(animated: true, completion: nil)

        return
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

// MARK: - INUIEditVoiceShortcutViewControllerDelegate

@available (iOS 12, *)
extension SettingsDetailViewController: INUIEditVoiceShortcutViewControllerDelegate {

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didUpdate voiceShortcut: INVoiceShortcut?,
                                         error: Error?) {
        if let error = error as NSError? {
            Log.error?.message("Error updating voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }

        if let voiceShortcut = voiceShortcut {
            Log.verbose?.message("Shortcut with ID \(voiceShortcut.identifier.uuidString) updated")
        }

        controller.dismiss(animated: true, completion: nil)

        return
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        Log.verbose?.message("Shortcut with ID \(deletedVoiceShortcutIdentifier.uuidString) deleted")

        controller.dismiss(animated: true, completion: nil)

        if let rowToDelete = self.form.rowBy(tag: deletedVoiceShortcutIdentifier.uuidString) as? ButtonRow,
            let section = rowToDelete.section, let path = rowToDelete.indexPath {
            section.remove(at: path.row)
        }

        return
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)

        return
    }
// swiftlint:disable:next file_length
}
