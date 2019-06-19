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
import Firebase

// swiftlint:disable:next type_body_length
class SettingsDetailViewController: FormViewController, TypedRowControllerType {

    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var detailGroup: String = "display"

    var doneButton: Bool = false

    private let realm = Current.realm()

    private var reorderingRows: [String: BaseRow] = [:]

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.doneButton {
            self.navigationItem.rightBarButtonItem = nil
            self.doneButton = false
        }
        self.onDismissCallback?(self)
    }

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
                +++ SwitchRow("openInChrome") {
                    $0.title = L10n.SettingsDetails.General.Chrome.title
                    $0.value = prefs.bool(forKey: "openInChrome")
                    }.onChange { row in
                        prefs.setValue(row.value, forKey: "openInChrome")
                        prefs.synchronize()
                }

                +++ PushRow<AppIcon>("appIcon") {
                        $0.title = L10n.SettingsDetails.General.AppIcon.title
                        $0.selectorTitle = $0.title
                        $0.options = AppIcon.allCases
                        $0.value = AppIcon.Release
                        if let altIconName = UIApplication.shared.alternateIconName,
                            let icon = AppIcon(rawValue: altIconName) {
                            $0.value = icon
                        }
                        $0.displayValueFor = { $0?.title }
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

            let zoneEntities = self.realm.objects(RLMZone.self).map { $0 }
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

        case "watch":
            self.title = L10n.SettingsDetails.Watch.title

            let infoBarButtonItem = Constants.helpBarButtonItem

            infoBarButtonItem.action = #selector(watchHelp)
            infoBarButtonItem.target = self

            self.navigationItem.rightBarButtonItem = infoBarButtonItem

            let existingComplications = self.realm.objects(WatchComplication.self)

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
                            $0.presentationMode = .show(controllerProvider: .callback {
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
                    Current.Log.verbose("Siri auth status \(status.rawValue)")
                }

                var entityIDs: [String] = []

                _ = HomeAssistantAPI.authenticatedAPI()?.GetStates().done { entities in
                    for entity in entities {
                        entityIDs.append(entity.ID)
                    }
                }

                self.form
                    +++ Section(header: L10n.SettingsDetails.Siri.Section.Generic.title, footer: "")
                    <<< ButtonRow {
                        $0.title = L10n.SiriShortcuts.Intents.SendLocation.title
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
                        $0.title = L10n.SiriShortcuts.Intents.FireEvent.title
                        $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                            return ShortcutEventConfigurator()
                            }, onDismiss: { vc in
                                _ = vc.navigationController?.popViewController(animated: true)
                        })
                    }

                    <<< ButtonRow {
                        $0.title = L10n.SiriShortcuts.Intents.GetCameraImage.title
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
                        $0.title = L10n.SiriShortcuts.Intents.RenderTemplate.title
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
                    let servicesSection = Section(header: L10n.SettingsDetails.Siri.Section.Services.title, footer: "")
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
                                Current.Log.error("Failed to fetch voice shortcuts with error: \(error)")
                            }
                            return
                        }

                        guard voiceShortcutsFromCenter.count > 0 else { return }

                        let existingSection = Section(header: L10n.SettingsDetails.Siri.Section.Existing.title,
                                                      footer: "") {
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
            self.title = L10n.SettingsDetails.Actions.title
            let actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

            let infoBarButtonItem = Constants.helpBarButtonItem

            infoBarButtonItem.action = #selector(actionsHelp)
            infoBarButtonItem.target = self

            self.navigationItem.rightBarButtonItem = infoBarButtonItem

            self.form
                // swiftlint:disable:next line_length
                +++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete, .Reorder], header: "", footer: L10n.SettingsDetails.Actions.footer) { section in
                        section.tag = "actions"
                        section.multivaluedRowToInsertAt = { _ -> ButtonRowWithPresent<ActionConfigurator> in
                            return self.getActionRow(nil)
                        }
                        section.addButtonProvider = { section in
                            return ButtonRow {
                                $0.title = L10n.addButtonLabel
                                $0.cellStyle = .value1
                                $0.tag = "add_action"
                            }.cellUpdate { cell, _ in
                                cell.textLabel?.textAlignment = .left
                            }
                        }

                        for action in actions {
                            section <<< getActionRow(action)
                        }
            }
        case "privacy":
            self.title = L10n.SettingsDetails.Privacy.title
            let infoBarButtonItem = Constants.helpBarButtonItem

            infoBarButtonItem.action = #selector(firebasePrivacy)
            infoBarButtonItem.target = self

            self.navigationItem.rightBarButtonItem = infoBarButtonItem

            self.form
                +++ Section(header: "", footer: L10n.SettingsDetails.Privacy.Messaging.description)
                <<< SwitchRow("messaging") {
                    $0.title = L10n.SettingsDetails.Privacy.Messaging.title
                    $0.value = prefs.bool(forKey: "messagingEnabled")
                }.onChange { row in
                    guard let rowVal = row.value else { return }
                    prefs.setValue(rowVal, forKey: "messagingEnabled")
                    prefs.synchronize()

                    Current.Log.warning("Firebase messaging is now: \(rowVal)")
                    Messaging.messaging().isAutoInitEnabled = rowVal
                }
                +++ Section(header: "", footer: L10n.SettingsDetails.Privacy.Crashlytics.description)
                <<< SwitchRow("crashlytics") {
                    $0.title = L10n.SettingsDetails.Privacy.Crashlytics.title
                    $0.value = prefs.bool(forKey: "crashlyticsEnabled")
                }.onChange { row in
                    guard let rowVal = row.value else { return }
                    Current.setCrashlyticsEnabled(enabled: rowVal)
                }
                +++ Section(header: "", footer: L10n.SettingsDetails.Privacy.Analytics.description)
                <<< SwitchRow("analytics") {
                    $0.title = L10n.SettingsDetails.Privacy.Analytics.title
                    $0.value = prefs.bool(forKey: "analyticsEnabled")
                    }.onChange { row in
                        guard let rowVal = row.value else { return }
                        prefs.setValue(rowVal, forKey: "analyticsEnabled")
                        prefs.synchronize()

                        Current.Log.warning("Firebase analytics is now: \(rowVal)")
                        Analytics.setAnalyticsCollectionEnabled(rowVal)
                }

        default:
            Current.Log.warning("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    @objc func firebasePrivacy(_ sender: Any) {
        openURLInBrowser(urlToOpen: URL(string: "https://firebase.google.com/support/privacy/")!)
    }

    @objc func actionsHelp(_ sender: Any) {
        openURLInBrowser(urlToOpen: URL(string: "https://companion.home-assistant.io/next/integrations/actions")!)
    }

    @objc func watchHelp(_ sender: Any) {
        openURLInBrowser(urlToOpen: URL(string: "https://companion.home-assistant.io/next/integrations/apple-watch")!)
    }

    override func tableView(_ tableView: UITableView, willBeginReorderingRowAtIndexPath indexPath: IndexPath) {
        let row = form[indexPath]
        guard let rowTag = row.tag else { return }
        reorderingRows[rowTag] = row

        super.tableView(tableView, willBeginReorderingRowAtIndexPath: indexPath)
    }

    @objc public func tableView(_ tableView: UITableView, didEndReorderingRowAtIndexPath indexPath: IndexPath) {
        guard let rowTag = form[indexPath].tag, let row = reorderingRows[rowTag],
            let actionsSection = row.section as? MultivaluedSection else { return }

        Current.Log.verbose("Setting action \(row) to position \(indexPath.row)")

        let rowsDict = actionsSection.allRows.enumerated().compactMap { (entry) -> (String, Int)? in
            // Current.Log.verbose("Map \(entry.element.indexPath) \(entry.element.tag)")
            guard let tag = entry.element.tag else { return nil }

            return (tag, entry.offset)
        }

        let rowPositions = Dictionary(uniqueKeysWithValues: rowsDict)

        realm.beginWrite()

        for storedAction in realm.objects(Action.self).sorted(byKeyPath: "Position") {
            guard let newPos = rowPositions[storedAction.ID] else { continue }
            storedAction.Position = newPos
            // Current.Log.verbose("Update action \(storedAction.ID) to pos \(newPos)")
        }

        try? realm.commitWrite()

        reorderingRows[rowTag] = nil
    }

    @objc func tableView(_ tableView: UITableView, didCancelReorderingRowAtIndexPath indexPath: IndexPath) {
        guard let rowTag = form[indexPath].tag else { return }
        reorderingRows[rowTag] = nil
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)

        let deletedIDs = rows.filter {
            guard let tag = $0.tag else { return false }
            return reorderingRows[tag] == nil
        }.compactMap { $0.tag }

        if deletedIDs.count == 0 { return }

        Current.Log.verbose("Rows removed \(rows), \(deletedIDs)")

        let realm = Realm.live()

        if (rows.first as? ButtonRowWithPresent<ActionConfigurator>) != nil {
            Current.Log.verbose("Removed row is ActionConfiguration \(deletedIDs)")
            // swiftlint:disable:next force_try
            try! realm.write {
                realm.delete(realm.objects(Action.self).filter("ID IN %@", deletedIDs))
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    func getActionRow(_ inputAction: Action?) -> ButtonRowWithPresent<ActionConfigurator> {
        var identifier = UUID().uuidString
        var title = L10n.ActionsConfigurator.title
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
                        Current.Log.verbose("Not saving action to DB and returning early!")
                        return
                    }

                    vc.row.title = vc.action.Name
                    vc.row.updateCell()

                    Current.Log.verbose("Saving action! \(vc.action)")

                    let realm = Current.realm()

                    do {
                        try realm.write {
                            realm.add(vc.action, update: true)
                        }
                    } catch let error as NSError {
                        Current.Log.error("Error while saving to Realm!: \(error)")
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
            return L10n.SettingsDetails.General.AppIcon.Enum.beta
        case .Dev:
            return L10n.SettingsDetails.General.AppIcon.Enum.dev
        case .Release:
            return L10n.SettingsDetails.General.AppIcon.Enum.release
        case .Black:
            return L10n.SettingsDetails.General.AppIcon.Enum.black
        case .Blue:
            return L10n.SettingsDetails.General.AppIcon.Enum.blue
        case .Green:
            return L10n.SettingsDetails.General.AppIcon.Enum.green
        case .Orange:
            return L10n.SettingsDetails.General.AppIcon.Enum.orange
        case .Purple:
            return L10n.SettingsDetails.General.AppIcon.Enum.purple
        case .Red:
            return L10n.SettingsDetails.General.AppIcon.Enum.red
        case .White:
            return L10n.SettingsDetails.General.AppIcon.Enum.white
        case .OldRelease:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldRelease
        case .OldBeta:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldBeta
        case .OldDev:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldDev
        }
    }
}

@available (iOS 12, *)
extension SettingsDetailViewController: INUIAddVoiceShortcutViewControllerDelegate {

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                        didFinishWith voiceShortcut: INVoiceShortcut?,
                                        error: Error?) {
        if let error = error as NSError? {
            Current.Log.error("Error adding voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }

        if let voiceShortcut = voiceShortcut {
            Current.Log.verbose("Shortcut with ID \(voiceShortcut.identifier.uuidString) added")

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
            Current.Log.error("Error updating voice shortcut: \(error)")
            controller.dismiss(animated: true, completion: nil)
            return
        }

        if let voiceShortcut = voiceShortcut {
            Current.Log.verbose("Shortcut with ID \(voiceShortcut.identifier.uuidString) updated")
        }

        controller.dismiss(animated: true, completion: nil)

        return
    }

    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                         didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        Current.Log.verbose("Shortcut with ID \(deletedVoiceShortcutIdentifier.uuidString) deleted")

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
