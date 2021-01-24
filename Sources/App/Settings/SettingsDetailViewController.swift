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
import CoreMotion
import FirebaseMessaging
import Version
import RealmSwift

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class SettingsDetailViewController: FormViewController, TypedRowControllerType {

    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var detailGroup: String = "display"

    var doneButton: Bool = false

    private static let iconSize = CGSize(width: 28, height: 28)

    private let realm = Current.realm()
    private var notificationTokens: [NotificationToken] = []
    private var notificationCenterTokens: [AnyObject] = []
    private var reorderingRows: [String: BaseRow] = [:]

    deinit {
        notificationCenterTokens.forEach(NotificationCenter.default.removeObserver)
    }

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
                +++ Section()
                <<< TextRow {
                    $0.title = L10n.SettingsDetails.General.DeviceName.title
                    $0.placeholder = Current.device.deviceName()
                    $0.value = Current.settingsStore.overrideDeviceName
                    $0.onChange { row in
                        Current.settingsStore.overrideDeviceName = row.value
                    }
                }

                <<< PushRow<AppIcon>("appIcon") {
                        $0.hidden = .isCatalyst
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

                +++ Section {
                    $0.hidden = .isNotCatalyst
                }
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.General.LaunchOnLogin.title

                    #if targetEnvironment(macCatalyst)
                    let launcherIdentifier = Constants.BundleID.appending(".Launcher")
                    $0.value = Current.macBridge.isLoginItemEnabled(forBundleIdentifier: launcherIdentifier)
                    $0.onChange { row in
                        let success = Current.macBridge.setLoginItem(
                            forBundleIdentifier: launcherIdentifier,
                            enabled: row.value ?? false
                        )
                        if !success {
                            row.value = Current.macBridge.isLoginItemEnabled(forBundleIdentifier: launcherIdentifier)
                            row.updateCell()
                        }
                    }
                    #endif
                }

                <<< PushRow<SettingsStore.LocationVisibility> {
                    $0.title = L10n.SettingsDetails.General.Visibility.title
                    $0.options = SettingsStore.LocationVisibility.allCases
                    $0.value = Current.settingsStore.locationVisibility
                    $0.displayValueFor = {
                        switch $0 ?? .dock {
                        case .dock: return L10n.SettingsDetails.General.Visibility.Options.dock
                        case .dockAndMenuBar: return L10n.SettingsDetails.General.Visibility.Options.dockAndMenuBar
                        case .menuBar: return L10n.SettingsDetails.General.Visibility.Options.menuBar
                        }
                    }
                    $0.onChange { row in
                        Current.settingsStore.locationVisibility = row.value ?? .dock
                    }
                }

                +++ Section {
                    $0.hidden = .function([], { _ in !Current.updater.isSupported })
                }
                <<< SwitchRow("checkForUpdates") {
                    $0.title = L10n.SettingsDetails.Updates.CheckForUpdates.title
                    $0.value = Current.settingsStore.privacy.updates
                    $0.onChange { row in
                        Current.settingsStore.privacy.updates = row.value ?? true
                    }
                }
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Updates.CheckForUpdates.includeBetas
                    $0.value = Current.settingsStore.privacy.updatesIncludeBetas
                    $0.onChange { row in
                        Current.settingsStore.privacy.updatesIncludeBetas = row.value ?? true
                    }
                }

                +++ PushRow<OpenInBrowser>("openInBrowser") {
                    $0.hidden = .isCatalyst
                    $0.title = L10n.SettingsDetails.General.OpenInBrowser.title

                    if let value = prefs.string(forKey: "openInBrowser").flatMap({ OpenInBrowser(rawValue: $0) }),
                        value.isInstalled {
                        $0.value = value
                    } else {
                        $0.value = .Safari
                    }
                    $0.selectorTitle = $0.title
                    $0.options = OpenInBrowser.allCases.filter { $0.isInstalled }
                    $0.displayValueFor = { $0?.title }
                }.onChange { row in
                    guard let browserChoice = row.value else { return }
                    prefs.setValue(browserChoice.rawValue, forKey: "openInBrowser")
                    prefs.synchronize()
                }

                <<< SwitchRow {
                    // mac has a system-level setting for state restoration
                    $0.hidden = .isCatalyst

                    $0.title = L10n.SettingsDetails.General.Restoration.title
                    $0.value = Current.settingsStore.restoreLastURL
                    $0.onChange { row in
                        Current.settingsStore.restoreLastURL = row.value ?? false
                    }
                }

                <<< PushRow<SettingsStore.PageZoom> { row in
                    row.title = L10n.SettingsDetails.General.PageZoom.title
                    row.options = SettingsStore.PageZoom.allCases

                    row.value = Current.settingsStore.pageZoom
                    row.onChange { row in
                        Current.settingsStore.pageZoom = row.value ?? .default
                    }
                }

        case "location":
            self.title = L10n.SettingsDetails.Location.title
            self.form
                +++ locationPermissionsSection()

                +++ Section(header: L10n.SettingsDetails.Location.Updates.header,
                            footer: L10n.SettingsDetails.Location.Updates.footer)
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Zone.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnZone")
                        $0.disabled = .location(conditions: [.permissionNotAlways, .accuracyNotFull])
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnZone")
                        }
                    })
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Background.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnBackgroundFetch")
                        $0.disabled = .location(conditions: [
                            .permissionNotAlways,
                            .accuracyNotFull,
                            .backgroundRefreshNotAvailable
                        ])
                        $0.hidden = .isCatalyst
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnBackgroundFetch")
                        }
                    })
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Significant.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnSignificant")
                        $0.disabled = .location(conditions: [.permissionNotAlways, .accuracyNotFull])
                    }.onChange({ (row) in
                        if let val = row.value {
                            prefs.set(val, forKey: "locationUpdateOnSignificant")
                        }
                    })
                <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Updates.Notification.title
                        $0.value = prefs.bool(forKey: "locationUpdateOnNotification")
                        $0.disabled = .location(conditions: [.permissionNotAlways, .accuracyNotFull])
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
                        $0.value = zone.location
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

        case "actions":
            self.title = L10n.SettingsDetails.Actions.title
            let actions = realm.objects(Action.self)
                .sorted(byKeyPath: "Position")
                .filter("Scene == nil")

            let infoBarButtonItem = Constants.helpBarButtonItem

            infoBarButtonItem.action = #selector(actionsHelp)
            infoBarButtonItem.target = self

            self.navigationItem.rightBarButtonItem = infoBarButtonItem

            let refreshControl = UIRefreshControl()
            tableView.refreshControl = refreshControl
            refreshControl.addTarget(self, action: #selector(refreshScenes(_:)), for: .valueChanged)

            let actionsFooter = Current.isCatalyst ?
                L10n.SettingsDetails.Actions.footerMac : L10n.SettingsDetails.Actions.footer

            form +++ MultivaluedSection(
                multivaluedOptions: [.Insert, .Delete, .Reorder],
                header: "",
                footer: actionsFooter
            ) { section in
                section.tag = "actions"
                section.multivaluedRowToInsertAt = { [unowned self] _ -> ButtonRowWithPresent<ActionConfigurator> in
                    return self.getActionRow(nil)
                }
                section.addButtonProvider = { _ in
                    return ButtonRow {
                        $0.title = L10n.addButtonLabel
                        $0.cellStyle = .value1
                        $0.tag = "add_action"
                    }.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .left
                    }
                }

                for action in actions.filter("isServerControlled == false") {
                    section <<< getActionRow(action)
                }
            }

            if let version = Current.serverVersion(), version >= .actionSyncing {
                form +++ RealmSection(
                    header: L10n.SettingsDetails.Actions.ActionsSynced.header,
                    footer: nil,
                    collection: AnyRealmCollection(actions.filter("isServerControlled == true")),
                    emptyRows: [
                        LabelRow {
                            $0.title = L10n.SettingsDetails.Actions.ActionsSynced.empty
                            $0.disabled = true
                        }
                    ], getter: { [weak self] in self?.getActionRow($0) },
                    didUpdate: { section, collection in
                        if collection.isEmpty {
                            section.footer = HeaderFooterView(
                                title: L10n.SettingsDetails.Actions.ActionsSynced.footerNoActions
                            )
                        } else {
                            section.footer = HeaderFooterView(
                                title: L10n.SettingsDetails.Actions.ActionsSynced.footer
                            )
                        }
                    }
                )
            }

            let scenes = realm.objects(RLMScene.self).sorted(byKeyPath: RLMScene.positionKeyPath)

            form +++ RealmSection<RLMScene>(
                header: L10n.SettingsDetails.Actions.Scenes.title,
                footer: L10n.SettingsDetails.Actions.Scenes.footer,
                collection: AnyRealmCollection(scenes),
                emptyRows: [
                    LabelRow {
                        $0.title = L10n.SettingsDetails.Actions.Scenes.empty
                        $0.disabled = true
                    }
                ], getter: {
                    Self.getSceneRows($0)
                }
            )

        case "privacy":
            self.title = L10n.SettingsDetails.Privacy.title
            let infoBarButtonItem = Constants.helpBarButtonItem

            infoBarButtonItem.action = #selector(firebasePrivacy)
            infoBarButtonItem.target = self

            self.navigationItem.rightBarButtonItem = infoBarButtonItem

            self.form
                +++ Section(header: nil, footer: L10n.SettingsDetails.Privacy.Messaging.description)
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.Messaging.title
                    $0.value = Current.settingsStore.privacy.messaging
                }.onChange { row in
                    Current.settingsStore.privacy.messaging = row.value ?? true
                    Messaging.messaging().isAutoInitEnabled = Current.settingsStore.privacy.messaging
                }
                +++ Section(
                    header: nil,
                    footer: L10n.SettingsDetails.Privacy.CrashReporting.description
                        + "\n\n" + L10n.SettingsDetails.Privacy.CrashReporting.sentry
                )
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.CrashReporting.title
                    $0.value = Current.settingsStore.privacy.crashes
                }.onChange { row in
                    Current.settingsStore.privacy.crashes = row.value ?? true
                }
                +++ Section(header: nil, footer: L10n.SettingsDetails.Privacy.Analytics.genericDescription)
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.Analytics.genericTitle
                    $0.value = Current.settingsStore.privacy.analytics
                }.onChange { row in
                    Current.settingsStore.privacy.analytics = row.value ?? true
                }
                +++ Section(header: nil, footer: L10n.SettingsDetails.Privacy.Alerts.description)
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.Alerts.title
                    $0.value = Current.settingsStore.privacy.alerts
                }.onChange { row in
                    Current.settingsStore.privacy.alerts = row.value ?? true
                }

        default:
            Current.Log.warning("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    @objc func firebasePrivacy(_ sender: Any) {
        openURLInBrowser(URL(string: "https://companion.home-assistant.io/app/ios/firebase-privacy")!, self)
    }

    @objc func actionsHelp(_ sender: Any) {
        openURLInBrowser(URL(string: "https://companion.home-assistant.io/app/ios/actions")!, self)
    }

    @objc func watchHelp(_ sender: Any) {
        openURLInBrowser(URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!, self)
    }

    override func tableView(_ tableView: UITableView, willBeginReorderingRowAtIndexPath indexPath: IndexPath) {
        let row = form[indexPath]
        guard let rowTag = row.tag else { return }
        reorderingRows[rowTag] = row

        super.tableView(tableView, willBeginReorderingRowAtIndexPath: indexPath)
    }

    private func updatePositions() {
        guard let actionsSection = form.sectionBy(tag: "actions") as? MultivaluedSection else {
            return
        }

        let rowsDict = actionsSection.allRows.enumerated().compactMap { (entry) -> (String, Int)? in
            // Current.Log.verbose("Map \(entry.element.indexPath) \(entry.element.tag)")
            guard let tag = entry.element.tag else { return nil }

            return (tag, entry.offset)
        }

        let rowPositions = Dictionary(uniqueKeysWithValues: rowsDict)

        realm.beginWrite()

        for storedAction in realm.objects(Action.self).sorted(byKeyPath: "Position") {
            guard let newPos = rowPositions[storedAction.ID] else { continue }
            storedAction.Position = Action.PositionOffset.manual.rawValue + newPos
            // Current.Log.verbose("Update action \(storedAction.ID) to pos \(newPos)")
        }

        try? realm.commitWrite()
    }

    @objc public func tableView(_ tableView: UITableView, didEndReorderingRowAtIndexPath indexPath: IndexPath) {
        let row = form[indexPath]
        Current.Log.verbose("Setting action \(row) to position \(indexPath.row)")

        updatePositions()

        reorderingRows[row.tag ?? ""] = nil
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

    @objc private func refreshScenes(_ sender: UIRefreshControl) {
        sender.beginRefreshing()

        firstly {
            Current.modelManager.fetch()
        }.ensure {
            sender.endRefreshing()
        }.cauterize()
    }

    static func getSceneRows(_ rlmScene: RLMScene) -> [BaseRow] {
        let switchRow = SwitchRow()
        let configure = ButtonRowWithPresent<ActionConfigurator> {
            $0.title = L10n.SettingsDetails.Actions.Scenes.customizeAction
            $0.disabled = .function([], { _ in switchRow.value == false })
            $0.cellUpdate { cell, row in
                cell.separatorInset = .zero
                cell.textLabel?.textAlignment = .natural
                cell.imageView?.image = UIImage(size: iconSize, color: .clear)
                if #available(iOS 13, *) {
                    cell.textLabel?.textColor = row.isDisabled == false ? Constants.tintColor : .tertiaryLabel
                } else {
                    cell.textLabel?.textColor = row.isDisabled == false ? Constants.tintColor : .gray
                }
            }

            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ActionConfigurator(action: rlmScene.actions.first!)
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? ActionConfigurator, vc.shouldSave, let realm = rlmScene.realm {
                    do {
                        try realm.write {
                            realm.add(vc.action, update: .all)
                        }
                    } catch {
                        Current.Log.error("Error while saving to Realm!: \(error)")
                    }
                }
            })
        }

        let scene = rlmScene.scene
        _ = with(switchRow) {
            $0.title = scene.FriendlyName ?? scene.ID
            $0.value = rlmScene.actionEnabled
            $0.cellUpdate { cell, _ in
                cell.imageView?.image =
                    scene.Icon
                        .flatMap({ MaterialDesignIcons(serversideValueNamed: $0) })?
                        .image(ofSize: iconSize, color: .black)
                        .withRenderingMode(.alwaysTemplate)
            }
            $0.onChange { row in
                do {
                    try rlmScene.realm?.write {
                        rlmScene.actionEnabled = row.value ?? true
                    }

                    configure.evaluateDisabled()
                } catch {
                    Current.Log.error("couldn't write action update: \(error)")
                }
            }
        }

        return [switchRow, configure]
    }

    // swiftlint:disable:next function_body_length
    func getActionRow(_ inputAction: Action?) -> ButtonRowWithPresent<ActionConfigurator> {
        var identifier = UUID().uuidString
        var title = L10n.ActionsConfigurator.title
        var action = inputAction

        if let passedAction = inputAction {
            identifier = passedAction.ID
            title = passedAction.Name
        }

        return ButtonRowWithPresent<ActionConfigurator> {
            $0.tag = identifier
            $0.title = title
            $0.cellStyle = .subtitle
            $0.displayValueFor = { _ in
                guard action == nil || action?.isInvalidated == false else { return nil }
                return action?.Text ?? L10n.ActionsConfigurator.Rows.Text.title
            }
            $0.cellSetup { cell, _ in
                if #available(iOS 13, *) {
                    cell.detailTextLabel?.textColor = .secondaryLabel
                } else {
                    cell.detailTextLabel?.textColor = .darkGray
                }
            }
            $0.cellUpdate { cell, _ in
                guard action == nil || action?.isInvalidated == false else { return }
                cell.imageView?.image = MaterialDesignIcons(named: action?.IconName ?? "")
                    .image(ofSize: Self.iconSize, color: .black)
                    .withRenderingMode(.alwaysTemplate)
            }
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                return ActionConfigurator(action: action)
            }, onDismiss: { [weak self] vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? ActionConfigurator {
                    if vc.shouldSave == false {
                        Current.Log.verbose("Not saving action to DB and returning early!")
                        return
                    }

                    action = vc.action
                    vc.row.tag = vc.action.ID
                    vc.row.title = vc.action.Name
                    vc.row.updateCell()

                    Current.Log.verbose("Saving action! \(vc.action)")

                    let realm = Current.realm()

                    do {
                        try realm.write {
                            realm.add(vc.action, update: .all)
                        }

                        self?.updatePositions()
                    } catch let error as NSError {
                        Current.Log.error("Error while saving to Realm!: \(error)")
                    }
                }
            })
        }
    }

    private func locationPermissionsSection() -> Section {
        let section = Section()

        section <<< locationPermissionRow()

        if #available(iOS 14, *) {
            section <<< locationAccuracyRow()
        }

        section <<< motionPermissionRow()

        section <<< backgroundRefreshRow()

        return section
    }

    private func locationPermissionRow() -> BaseRow {
        class PermissionWatchingDelegate: NSObject, CLLocationManagerDelegate {
            let row: LocationPermissionRow

            init(row: LocationPermissionRow) {
                self.row = row
            }

            @available(iOS 14, *)
            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                row.value = manager.authorizationStatus
                row.updateCell()
            }

            func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
                row.value = status
                row.updateCell()
            }
        }

        return LocationPermissionRow("locationPermission") {
            let locationManager = CLLocationManager()
            let permissionDelegate = PermissionWatchingDelegate(row: $0)

            $0.title = L10n.SettingsDetails.Location.LocationPermission.title

            $0.cellUpdate { cell, _ in
                // setting the delegate also has the side effect of triggering a status update, which sets the value
                locationManager.delegate = permissionDelegate

                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            $0.onCellSelection { _, row in
                if CLLocationManager.authorizationStatus() == .notDetermined {
                    locationManager.requestAlwaysAuthorization()
                } else {
                    UIApplication.shared.openSettings(destination: .location)
                }

                row.deselect(animated: true)
            }
        }
    }

    @available(iOS 14, *)
    private func locationAccuracyRow() -> BaseRow {
        class PermissionWatchingDelegate: NSObject, CLLocationManagerDelegate {
            let row: LocationAccuracyRow

            init(row: LocationAccuracyRow) {
                self.row = row
            }

            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                row.value = manager.accuracyAuthorization
                row.updateCell()
            }
        }

        return LocationAccuracyRow("locationAccuracy") {
            let locationManager = CLLocationManager()
            let permissionDelegate = PermissionWatchingDelegate(row: $0)

            $0.title = L10n.SettingsDetails.Location.LocationAccuracy.title

            $0.cellUpdate { cell, _ in
                // setting the delegate also has the side effect of triggering a status update, which sets the value
                locationManager.delegate = permissionDelegate

                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            $0.onCellSelection { _, row in
                UIApplication.shared.openSettings(destination: .location)
                row.deselect(animated: true)
            }
        }
    }

    private func motionPermissionRow() -> BaseRow {
        return MotionPermissionRow { row in
            func update(isInitial: Bool) {
                row.value = CMMotionActivityManager.authorizationStatus()

                if !isInitial {
                    row.updateCell()
                }
            }

            row.hidden = .init(booleanLiteral: !Current.motion.isActivityAvailable())

            row.title = L10n.SettingsDetails.Location.MotionPermission.title
            update(isInitial: true)

            row.cellUpdate { cell, _ in
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }

            let manager = CMMotionActivityManager()
            row.onCellSelection { _, row in
                if CMMotionActivityManager.authorizationStatus() == .notDetermined {
                    let now = Date()
                    manager.queryActivityStarting(from: now, to: now, to: .main, withHandler: { _, _ in
                        update(isInitial: false)
                    })
                } else {
                    // if the user changes the value in settings, we'll be killed, so we don't need to watch anything
                    UIApplication.shared.openSettings(destination: .motion)
                }

                row.deselect(animated: true)
            }
        }
    }

    private func backgroundRefreshRow() -> BaseRow {
        return BackgroundRefreshStatusRow("backgroundRefresh") { row in
            func updateRow(isInitial: Bool) {
                row.value = UIApplication.shared.backgroundRefreshStatus

                if !isInitial {
                    row.updateCell()
                }
            }

            notificationCenterTokens.append(NotificationCenter.default.addObserver(
                forName: UIApplication.backgroundRefreshStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateRow(isInitial: false)
            })

            updateRow(isInitial: true)

            row.hidden = .isCatalyst
            row.title = L10n.SettingsDetails.Location.BackgroundRefresh.title
            row.cellUpdate { cell, _ in
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            row.onCellSelection { _, row in
                UIApplication.shared.openSettings(destination: .backgroundRefresh)
                row.deselect(animated: true)
            }
        }
    }
}

enum AppIcon: String, CaseIterable {
    case Release = "release"
    case Beta = "beta"
    case Dev = "dev"
    case Black = "black"
    case Blue = "blue"
    case CaribbeanGreen = "caribbean-green"
    case CornflowerBlue = "cornflower-blue"
    case Crimson = "crimson"
    case ElectricViolet = "electric-violet"
    case FireOrange = "fire-orange"
    case Green = "green"
    case HaBlue = "ha-blue"
    case OldBeta = "old-beta"
    case OldDev = "old-dev"
    case OldRelease = "old-release"
    case Orange = "orange"
    case Pink = "pink"
    case Purple = "purple"
    case Red = "red"
    case White = "white"
    case BiPride = "bi_pride"
    case POCPride = "POC_pride"
    case Rainbow = "rainbow"
    case RainbowInvert = "rainbow_invert"
    case Trans = "trans"

    var title: String {
        switch self {
        case .Release:
            return L10n.SettingsDetails.General.AppIcon.Enum.release
        case .Beta:
            return L10n.SettingsDetails.General.AppIcon.Enum.beta
        case .Dev:
            return L10n.SettingsDetails.General.AppIcon.Enum.dev
        case .Black:
            return L10n.SettingsDetails.General.AppIcon.Enum.black
        case .Blue:
            return L10n.SettingsDetails.General.AppIcon.Enum.blue
        case .CaribbeanGreen:
            return L10n.SettingsDetails.General.AppIcon.Enum.caribbeanGreen
        case .CornflowerBlue:
            return L10n.SettingsDetails.General.AppIcon.Enum.cornflowerBlue
        case .Crimson:
            return L10n.SettingsDetails.General.AppIcon.Enum.crimson
        case .ElectricViolet:
            return L10n.SettingsDetails.General.AppIcon.Enum.electricViolet
        case .FireOrange:
            return L10n.SettingsDetails.General.AppIcon.Enum.fireOrange
        case .Green:
            return L10n.SettingsDetails.General.AppIcon.Enum.green
        case .HaBlue:
            return L10n.SettingsDetails.General.AppIcon.Enum.haBlue
        case .OldBeta:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldBeta
        case .OldDev:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldDev
        case .OldRelease:
            return L10n.SettingsDetails.General.AppIcon.Enum.oldRelease
        case .Orange:
            return L10n.SettingsDetails.General.AppIcon.Enum.orange
        case .Pink:
            return L10n.SettingsDetails.General.AppIcon.Enum.pink
        case .Purple:
            return L10n.SettingsDetails.General.AppIcon.Enum.purple
        case .Red:
            return L10n.SettingsDetails.General.AppIcon.Enum.red
        case .White:
            return L10n.SettingsDetails.General.AppIcon.Enum.white
        case .BiPride:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideBi
        case .POCPride:
            return L10n.SettingsDetails.General.AppIcon.Enum.pridePoc
        case .Rainbow:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideRainbow
        case .RainbowInvert:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideRainbowInvert
        case .Trans:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideTrans
        }
    }
}

enum OpenInBrowser: String, CaseIterable {
    case Chrome
    case Firefox
    case Safari
    case SafariInApp

    var title: String {
        switch self {
        case .Chrome:
            return L10n.SettingsDetails.General.OpenInBrowser.chrome
        case .Firefox:
            return L10n.SettingsDetails.General.OpenInBrowser.firefox
        case .Safari:
            if #available(iOS 14, *) {
                return L10n.SettingsDetails.General.OpenInBrowser.default
            } else {
                return L10n.SettingsDetails.General.OpenInBrowser.safari
            }
        case .SafariInApp:
            return L10n.SettingsDetails.General.OpenInBrowser.safariInApp
        }
    }

    var isInstalled: Bool {
        switch self {
        case .Chrome:
            return OpenInChromeController.sharedInstance.isChromeInstalled()
        case .Firefox:
            return OpenInFirefoxControllerSwift().isFirefoxInstalled()
        default:
            return true
        }
    }
}
