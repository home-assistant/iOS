import Communicator
import Eureka
import Foundation
import PromiseKit
import RealmSwift
import Shared
import Version

class ComplicationListViewController: HAFormViewController {
    @objc private func add(_ sender: UIBarButtonItem) {
        let editListViewController = ComplicationFamilySelectViewController(
            allowMultiple: supportsMultipleComplications,
            currentFamilies: Set(Current.realm().objects(WatchComplication.self).map(\.Family))
        )
        editListViewController.onDismissCallback = { $0.dismiss(animated: true, completion: nil) }
        let navigationController = UINavigationController(rootViewController: editListViewController)
        present(navigationController, animated: true, completion: nil)
    }

    private var supportsMultipleComplications: Bool {
        guard let string = Communicator.shared.mostRecentlyReceievedContext.content["watchVersion"] as? String else {
            return false
        }
        do {
            let version = try Version(string)
            return version >= Version(major: 7)
        } catch {
            Current.Log.error("failed to parse \(string), saying we're not 7+")
            return false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsDetails.Watch.title

        form +++ InfoLabelRow {
            $0.title = L10n.Watch.Configurator.List.description
            $0.displayType = .primary
        }

            <<< LearnMoreButtonRow {
                $0.value = URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!
            }

        form +++ InfoLabelRow {
            $0.title = L10n.Watch.Configurator.Warning.templatingAdmin
        }

        form +++ Section(
            header: L10n.Watch.Configurator.List.ManualUpdates.title,
            footer: L10n.Watch.Configurator.List.ManualUpdates.footer
        )

            <<< LabelRow { row in
                row.title = L10n.Watch.Configurator.List.ManualUpdates.remaining

                func updateRow(for state: WatchState) {
                    switch state {
                    case .notPaired:
                        row.value = L10n.Watch.Configurator.List.ManualUpdates.State.notPaired
                    case .paired(.notInstalled):
                        row.value = L10n.Watch.Configurator.List.ManualUpdates.State.notInstalled
                    case .paired(.installed(.notEnabled, _)):
                        row.value = L10n.Watch.Configurator.List.ManualUpdates.State.notEnabled
                    case let .paired(.installed(.enabled(numberOfUpdatesAvailableToday: remaining), _)):
                        row.value = NumberFormatter.localizedString(from: NSNumber(value: remaining), number: .none)
                    }

                    row.updateCell()
                }

                updateRow(for: Communicator.shared.currentWatchState)

                let stateObserver = WatchState.observe { watchState in
                    DispatchQueue.main.async {
                        updateRow(for: watchState)
                    }
                }

                let updateToken = NotificationCenter.default.addObserver(
                    forName: NotificationCommandManager.didUpdateComplicationsNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    updateRow(for: Communicator.shared.currentWatchState)
                }

                after(life: self).done {
                    NotificationCenter.default.removeObserver(updateToken)
                    WatchState.unobserve(stateObserver)
                }
            }

            <<< ButtonRowWithLoading {
                $0.title = L10n.Watch.Configurator.List.ManualUpdates.manuallyUpdate
                $0.onCellSelection { [weak self] _, row in
                    row.value = true
                    row.updateCell()

                    Current.notificationManager.commandManager.updateComplications().ensure {
                        row.value = false
                        row.updateCell()
                    }.catch { error in
                        let alert = UIAlertController(
                            title: L10n.errorLabel,
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }

        // Load complications from GRDB
        loadComplicationsFromGRDB()

        form +++ ButtonRow {
            $0.title = L10n.addButtonLabel
            $0.onCellSelection { [weak self] _, _ in
                guard let self else { return }
                do {
                    let currentFamilies = try Set(WatchComplicationGRDB.all().map(\.Family))
                    let editListViewController = ComplicationFamilySelectViewController(
                        allowMultiple: supportsMultipleComplications,
                        currentFamilies: currentFamilies
                    )
                    editListViewController.onDismissCallback = { [weak self] _ in
                        $0.dismiss(animated: true) {
                            // Reload complications after adding
                            self?.reloadComplications()
                        }
                    }
                    let navigationController = UINavigationController(rootViewController: editListViewController)
                    present(navigationController, animated: true, completion: nil)
                } catch {
                    Current.Log.error("Failed to fetch complications: \(error)")
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadComplications()
    }

    private func reloadComplications() {
        // Remove existing complication sections
        let sectionsToRemove = form.allSections.filter { section in
            ComplicationGroup.allCases.contains { $0.name == section.header?.title }
        }
        sectionsToRemove.forEach { form.remove(at: $0.index!) }

        // Reload from GRDB
        loadComplicationsFromGRDB()
    }

    private func loadComplicationsFromGRDB() {
        do {
            let allComplications = try WatchComplicationGRDB.all()

            for group in ComplicationGroup.allCases.sorted() {
                let familyItems = allComplications
                    .filter { group.members.map(\.rawValue).contains($0.rawFamily) }
                    .sorted { $0.rawFamily < $1.rawFamily }

                let section = Section(header: group.name, footer: group.description)
                
                for complication in familyItems {
                    section <<< ButtonRow {
                        $0.cellStyle = .value1
                        $0.title = complication.Family.shortName
                        $0.value = complication.displayName
                        $0.cellUpdate { cell, row in
                            cell.detailTextLabel?.text = row.value
                        }
                        $0.presentationMode = .show(controllerProvider: .callback {
                            ComplicationEditViewController(config: complication)
                        }, onDismiss: { [weak self] vc in
                            _ = vc.navigationController?.popViewController(animated: true)
                            // Reload after edit
                            self?.reloadComplications()
                        })
                    }
                }

                // Only add section if it has items
                if !familyItems.isEmpty {
                    // Insert before the "Add" button row
                    let addButtonIndex = form.allRows.firstIndex { $0.tag == nil && $0.title == L10n.addButtonLabel }
                    if let insertIndex = addButtonIndex, let sectionIndex = form.allSections.firstIndex(where: { $0.contains(where: { $0.indexPath?.row == insertIndex }) }) {
                        form.insert(section, at: sectionIndex)
                    } else {
                        form +++ section
                    }
                }
            }
        } catch {
            Current.Log.error("Failed to load complications from GRDB: \(error)")
        }
    }
}
