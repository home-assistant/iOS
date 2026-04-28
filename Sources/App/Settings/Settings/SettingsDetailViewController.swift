import Eureka
import PromiseKit
import RealmSwift
import Shared
import UIKit

enum SettingsDetailsGroup: String {
    case display
    case actions
}

class SettingsDetailViewController: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var detailGroup: SettingsDetailsGroup = .display

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
        case .actions:
            setupActionsSettings()
        default:
            Current.Log.warning("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        // Log in case user is running with internal URL set but not configured local access
        for server in Current.servers.all {
            if server.info.connection.hasInternalURLSet,
               server.info.connection.internalSSIDs?.isEmpty ?? true,
               server.info.connection.internalHardwareAddresses?.isEmpty ?? true {
                let message =
                    "Server \(server.info.name) - Internal URL set but no internal SSIDs or hardware addresses set"
                Current.Log.error(message)
                Current.clientEventStore.addEvent(.init(text: message, type: .settings))
            }
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
                cell.textLabel?.textColor = row.isDisabled == false ? AppConstants.tintColor : .tertiaryLabel
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
                cell.detailTextLabel?.textColor = .secondaryLabel
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
                    defer {
                        if vc.shouldOpenAutomationEditor {
                            vc.navigationController?.dismiss(animated: true, completion: {
                                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                                    .done { controller in
                                        controller.openActionAutomationEditor(actionId: vc.action.ID)
                                    }
                            })
                        }
                    }

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

    // MARK: - Actions Settings Setup

    private func setupActionsSettings() {
        title = L10n.SettingsDetails.LegacyActions.title

        // Disclaimer placeholder shown before actions content
        form +++ Section {
            $0.tag = "actions_disclaimer"
        }
            <<< InfoLabelRow {
                $0.title = L10n.LegacyActions.disclaimer
            }

        form +++ manualActionsSection()
        form +++ serverControlledActionsSection()
        form +++ serverActionsUpdateButton()
    }

    private func manualActionsSection() -> MultivaluedSection {
        let actions = realm.objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil")

        let section = MultivaluedSection(
            multivaluedOptions: [.Delete, .Reorder],
            header: ""
        ) { section in
            section.tag = "actions"

            for action in actions.filter("isServerControlled == false") {
                section <<< getActionRow(action)
            }
        }

        return section
    }

    private func serverControlledActionsSection() -> RealmSection<Action> {
        let actions = realm.objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil")

        return RealmSection(
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
    }

    private func serverActionsUpdateButton() -> Section {
        Section()
            <<< ButtonRow {
                $0.title = L10n.SettingsDetails.Actions.ServerControlled.Update.title
                $0.onCellSelection { _, _ in
                    let result = Current.modelManager.fetch()
                    result.pipe { result in
                        switch result {
                        case .fulfilled:
                            break
                        case let .rejected(error):
                            Current.Log.error("Failed to manually update server Actions: \(error.localizedDescription)")
                        }
                    }
                }
            }
    }
}
