import CoreMotion
import Eureka
import FirebaseMessaging
import Intents
import IntentsUI
import PromiseKit
import RealmSwift
import Shared
import UIKit
import Version

class SettingsDetailViewController: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var detailGroup: String = "display"

    var doneButton: Bool = false

    private let realm = Current.realm()
    private var notificationTokens: [NotificationToken] = []
    private var notificationCenterTokens: [AnyObject] = []
    private var reorderingRows: [String: BaseRow] = [:]

    deinit {
        notificationCenterTokens.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if doneButton {
            navigationItem.rightBarButtonItem = nil
            doneButton = false
        }
        onDismissCallback?(self)
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        if doneButton {
            let closeSelector = #selector(SettingsDetailViewController.closeSettingsDetailView(_:))
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: closeSelector
            )
            navigationItem.setRightBarButton(doneButton, animated: true)
        }

        switch detailGroup {
        case "general":
            title = L10n.SettingsDetails.General.title

            form
                +++ Section {
                    $0.hidden = .isCatalyst
                }

                <<< PushRow<AppIcon>("appIcon") {
                    $0.hidden = .isCatalyst
                    $0.title = L10n.SettingsDetails.General.AppIcon.title
                    $0.selectorTitle = $0.title
                    $0.options = AppIcon.allCases.sorted { a, b in
                        switch (a.isDefault, b.isDefault) {
                        case (true, false): return true
                        case (false, true): return false
                        default:
                            // swift sort isn't stable
                            return AppIcon.allCases.firstIndex(of: a)! < AppIcon.allCases.firstIndex(of: b)!
                        }
                    }
                    $0.value = AppIcon.Release
                    if let altIconName = UIApplication.shared.alternateIconName,
                       let icon = AppIcon(rawValue: altIconName) {
                        $0.value = icon
                    }
                    $0.displayValueFor = { $0?.title }
                }.onPresent { _, to in
                    to.selectableRowCellUpdate = { cell, row in
                        cell.height = { 72 }
                        cell.imageView?.layer.masksToBounds = true
                        cell.imageView?.layer.cornerRadius = 12.63
                        guard let newIcon = row.selectableValue else { return }
                        cell.imageView?.image = UIImage(named: newIcon.rawValue)

                        cell.textLabel?.text = newIcon.title
                    }
                }.onChange { row in
                    let iconName = row.value?.iconName
                    UIApplication.shared.setAlternateIconName(iconName) { error in
                        Current.Log
                            .info("set icon to \(String(describing: iconName)) error: \(String(describing: error))")
                    }
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
                    $0.tag = "locationVisibility"
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

                <<< ButtonRow { row in
                    row.title = L10n.SettingsDetails.General.MenuBarText.title
                    row.cellStyle = .value1
                    row.value = Current.settingsStore.menuItemTemplate?.template
                    row.displayValueFor = { $0 }
                    row.hidden = .function(["locationVisibility"], { form in
                        if let row = form
                            .rowBy(tag: "locationVisibility") as? PushRow<SettingsStore.LocationVisibility> {
                            return row.value?.isStatusItemVisible == false
                        } else {
                            return true
                        }
                    })
                    row.presentationMode = .show(controllerProvider: .callback(builder: {
                        if let current = Current.settingsStore.menuItemTemplate {
                            return TemplateEditViewController(
                                server: current.server,
                                initial: current.template,
                                saveHandler: { Current.settingsStore.menuItemTemplate = ($0, $1) }
                            )
                        } else {
                            return UIViewController()
                        }
                    }), onDismiss: { [weak self, row] _ in
                        row.value = Current.settingsStore.menuItemTemplate?.template
                        self?.navigationController?.popViewController(animated: true)
                    })
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
                    $0.options = OpenInBrowser.allCases.filter(\.isInstalled)
                    $0.displayValueFor = { $0?.title }
                }.onChange { row in
                    guard let browserChoice = row.value else { return }
                    prefs.setValue(browserChoice.rawValue, forKey: "openInBrowser")
                }

                <<< SwitchRow("openInPrivateTab") {
                    $0.hidden = .function(["openInBrowser"], { form in
                        if let row = form
                            .rowBy(tag: "openInBrowser") as? PushRow<OpenInBrowser> {
                            return row.value?.supportsPrivateTabs == false
                        } else {
                            return true
                        }
                    })
                    $0.title = L10n.SettingsDetails.General.OpenInPrivateTab.title
                    $0.value = prefs.bool(forKey: "openInPrivateTab")
                }.onChange { row in
                    prefs.setValue(row.value, forKey: "openInPrivateTab")
                }

                <<< SwitchRow("confirmBeforeOpeningUrl") {
                    $0.title = L10n.SettingsDetails.Notifications.PromptToOpenUrls.title
                    $0.value = prefs.bool(forKey: "confirmBeforeOpeningUrl")
                }.onChange { row in
                    prefs.setValue(row.value, forKey: "confirmBeforeOpeningUrl")
                }

                +++ SwitchRow {
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

                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.General.PinchToZoom.title
                    $0.hidden = .isCatalyst
                    $0.value = Current.settingsStore.pinchToZoom
                    $0.onChange { row in
                        Current.settingsStore.pinchToZoom = row.value ?? false
                    }
                }

                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.General.FullScreen.title
                    $0.hidden = .isCatalyst
                    $0.value = Current.settingsStore.fullScreen
                    $0.onChange { row in
                        Current.settingsStore.fullScreen = row.value ?? false
                    }
                }

        case "location":
            title = L10n.SettingsDetails.Location.title
            form
                +++ locationPermissionsSection()

                +++ ButtonRow {
                    $0.title = L10n.Settings.LocationHistory.title
                    $0.presentationMode = .show(controllerProvider: .callback(builder: {
                        LocationHistoryListViewController()
                    }), onDismiss: nil)
                }

                <<< ButtonRowWithLoading {
                    $0.title = L10n.SettingsDetails.Location.updateLocation
                    $0.onCellSelection { [weak self] _, row in
                        row.value = true
                        row.updateCell()

                        firstly {
                            HomeAssistantAPI.manuallyUpdate(
                                applicationState: UIApplication.shared.applicationState,
                                type: .userRequested
                            )
                        }.ensure {
                            row.value = false
                            row.updateCell()
                        }.catch { error in
                            let alert = UIAlertController(
                                title: nil,
                                message: error.localizedDescription,
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
                            self?.present(alert, animated: true, completion: nil)
                        }
                    }
                }

                +++ Section(
                    header: L10n.SettingsDetails.Location.Updates.header,
                    footer: L10n.SettingsDetails.Location.Updates.footer
                )
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Zone.title
                    $0.value = Current.settingsStore.locationSources.zone
                    $0.disabled = .location(conditions: [.permissionNotAlways, .accuracyNotFull])
                }.onChange({ row in
                    Current.settingsStore.locationSources.zone = row.value ?? true
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Background.title
                    $0.value = Current.settingsStore.locationSources.backgroundFetch
                    $0.disabled = .location(conditions: [
                        .permissionNotAlways,
                        .backgroundRefreshNotAvailable,
                    ])
                    $0.hidden = .isCatalyst
                }.onChange({ row in
                    Current.settingsStore.locationSources.backgroundFetch = row.value ?? true
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Significant.title
                    $0.value = Current.settingsStore.locationSources.significantLocationChange
                    $0.disabled = .location(conditions: [.permissionNotAlways])
                }.onChange({ row in
                    Current.settingsStore.locationSources.significantLocationChange = row.value ?? true
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Notification.title
                    $0.value = Current.settingsStore.locationSources.pushNotifications
                    $0.disabled = .location(conditions: [.permissionNotAlways])
                }.onChange({ row in
                    Current.settingsStore.locationSources.pushNotifications = row.value ?? true
                })

            let zoneEntities = realm.objects(RLMZone.self)
            for zone in zoneEntities {
                form
                    +++ Section(header: zone.Name, footer: "") {
                        $0.tag = zone.identifier
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
                        $0.hidden = Condition(booleanLiteral: zone.BeaconUUID == nil)
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconMajor.title
                        if let major = zone.BeaconMajor.value {
                            $0.value = String(describing: major)
                        } else {
                            $0.value = L10n.SettingsDetails.Location.Zones.Beacon.PropNotSet.value
                        }
                        $0.hidden = Condition(booleanLiteral: zone.BeaconMajor.value == nil)
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconMinor.title
                        if let minor = zone.BeaconMinor.value {
                            $0.value = String(describing: minor)
                        } else {
                            $0.value = L10n.SettingsDetails.Location.Zones.Beacon.PropNotSet.value
                        }
                        $0.hidden = Condition(booleanLiteral: zone.BeaconMinor.value == nil)
                    }
            }
            if zoneEntities.count > 0 {
                form +++ InfoLabelRow {
                    $0.title = L10n.SettingsDetails.Location.Zones.footer
                }
            }

        case "actions":
            title = L10n.SettingsDetails.Actions.title
            let actions = realm.objects(Action.self)
                .sorted(byKeyPath: "Position")
                .filter("Scene == nil")

            let actionsFooter = Current.isCatalyst ?
                L10n.SettingsDetails.Actions.footerMac : L10n.SettingsDetails.Actions.footer

            form +++ MultivaluedSection(
                multivaluedOptions: [.Insert, .Delete, .Reorder],
                header: "",
                footer: actionsFooter
            ) { section in
                section.tag = "actions"
                section.multivaluedRowToInsertAt = { [weak self] _ -> ButtonRowWithPresent<ActionConfigurator> in
                    self?.getActionRow(nil) ?? .init()
                }
                section.addButtonProvider = { _ in
                    ButtonRow {
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

            form +++ RealmSection(
                header: L10n.SettingsDetails.Actions.ActionsSynced.header,
                footer: nil,
                collection: AnyRealmCollection(actions.filter("isServerControlled == true")),
                emptyRows: [
                    LabelRow {
                        $0.title = L10n.SettingsDetails.Actions.ActionsSynced.empty
                        $0.disabled = true
                    },
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

            let scenes = realm.objects(RLMScene.self).sorted(byKeyPath: RLMScene.positionKeyPath)

            form +++ RealmSection<RLMScene>(
                header: L10n.SettingsDetails.Actions.Scenes.title,
                footer: L10n.SettingsDetails.Actions.Scenes.footer,
                collection: AnyRealmCollection(scenes),
                emptyRows: [
                    LabelRow {
                        $0.title = L10n.SettingsDetails.Actions.Scenes.empty
                        $0.disabled = true
                    },
                ], getter: {
                    Self.getSceneRows($0)
                }
            )

        case "privacy":
            title = L10n.SettingsDetails.Privacy.title

            form
                +++ Section(header: nil, footer: L10n.SettingsDetails.Privacy.Messaging.description)
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.Messaging.title
                    $0.value = Current.settingsStore.privacy.messaging
                }.onChange { row in
                    Current.settingsStore.privacy.messaging = row.value ?? true
                    Messaging.messaging().isAutoInitEnabled = Current.settingsStore.privacy.messaging
                }
                +++ Section(header: nil, footer: L10n.SettingsDetails.Privacy.Alerts.description)
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.Alerts.title
                    $0.value = Current.settingsStore.privacy.alerts
                }.onChange { row in
                    Current.settingsStore.privacy.alerts = row.value ?? true
                }
                +++ Section(
                    header: nil,
                    footer: L10n.SettingsDetails.Privacy.CrashReporting.description
                ) {
                    $0.hidden = .init(booleanLiteral: !Current.crashReporter.hasCrashReporter)
                }
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.CrashReporting.title
                    $0.value = Current.settingsStore.privacy.crashes
                }.onChange { row in
                    Current.settingsStore.privacy.crashes = row.value ?? true
                }
                +++ Section(header: nil, footer: L10n.SettingsDetails.Privacy.Analytics.genericDescription) {
                    $0.hidden = .init(booleanLiteral: !Current.crashReporter.hasAnalytics)
                }
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Privacy.Analytics.genericTitle
                    $0.value = Current.settingsStore.privacy.analytics
                }.onChange { row in
                    Current.settingsStore.privacy.analytics = row.value ?? true
                }

        default:
            Current.Log.warning("Something went wrong, no settings detail group named \(detailGroup)")
        }
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

        let rowsDict = actionsSection.allRows.enumerated().compactMap { entry -> (String, Int)? in
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
        }.compactMap(\.tag)

        if deletedIDs.count == 0 { return }

        Current.Log.verbose("Rows removed \(rows), \(deletedIDs)")

        let realm = Realm.live()

        if (rows.first as? ButtonRowWithPresent<ActionConfigurator>) != nil {
            Current.Log.verbose("Removed row is ActionConfiguration \(deletedIDs)")
            realm.reentrantWrite {
                realm.delete(realm.objects(Action.self).filter("ID IN %@", deletedIDs))
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    static func getSceneRows(_ rlmScene: RLMScene) -> [BaseRow] {
        let switchRow = SwitchRow()
        let configure = ButtonRowWithPresent<ActionConfigurator> {
            $0.title = L10n.SettingsDetails.Actions.Scenes.customizeAction
            $0.disabled = .function([], { _ in switchRow.value == false })
            $0.cellUpdate { cell, row in
                cell.separatorInset = .zero
                cell.textLabel?.textAlignment = .natural
                cell.imageView?.image = UIImage(size: MaterialDesignIcons.settingsIconSize, color: .clear)
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
                    realm.reentrantWrite {
                        realm.add(vc.action, update: .all)
                    }
                }
            })
        }

        _ = with(switchRow) {
            $0.title = rlmScene.name ?? rlmScene.identifier
            $0.value = rlmScene.actionEnabled
            $0.cellUpdate { cell, _ in
                cell.imageView?.image =
                    rlmScene.icon
                        .flatMap({ MaterialDesignIcons(serversideValueNamed: $0) })?
                        .settingsIcon(for: cell.traitCollection)
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
                    .settingsIcon(for: cell.traitCollection)
            }
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ActionConfigurator(action: action)
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
                    realm.reentrantWrite {
                        realm.add(vc.action, update: .all)
                    }.done {
                        self?.updatePositions()
                    }.cauterize()
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

    private func backgroundRefreshRow() -> BaseRow {
        BackgroundRefreshStatusRow("backgroundRefresh") { row in
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
    case Classic = "classic"
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
    case NonBinary = "non-binary"
    case Rainbow = "rainbow"
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
        case .Classic:
            return L10n.SettingsDetails.General.AppIcon.Enum.classic
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
        case .Trans:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideTrans
        case .NonBinary:
            return L10n.SettingsDetails.General.AppIcon.Enum.prideNonBinary
        }
    }

    var isDefault: Bool {
        switch Current.appConfiguration {
        case .Debug where self == .Dev: return true
        case .Beta where self == .Beta: return true
        case .Release where self == .Release: return true
        default: return false
        }
    }

    var iconName: String? {
        if isDefault {
            return nil
        } else {
            return rawValue
        }
    }
}

enum OpenInBrowser: String, CaseIterable {
    case Chrome
    case Firefox
    case FirefoxFocus
    case FirefoxKlar
    case Safari
    case SafariInApp

    var title: String {
        switch self {
        case .Chrome:
            return L10n.SettingsDetails.General.OpenInBrowser.chrome
        case .Firefox:
            return L10n.SettingsDetails.General.OpenInBrowser.firefox
        case .FirefoxFocus:
            return L10n.SettingsDetails.General.OpenInBrowser.firefoxFocus
        case .FirefoxKlar:
            return L10n.SettingsDetails.General.OpenInBrowser.firefoxKlar
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
        case .FirefoxFocus:
            return OpenInFirefoxControllerSwift(type: .focus).isFirefoxInstalled()
        case .FirefoxKlar:
            return OpenInFirefoxControllerSwift(type: .klar).isFirefoxInstalled()
        default:
            return true
        }
    }

    var supportsPrivateTabs: Bool {
        switch self {
        case .Firefox:
            return true
        default:
            return false
        }
    }
}
