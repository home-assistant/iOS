import CoreMotion
import Eureka
import Foundation
import PromiseKit
import Shared

class SensorListViewController: HAFormViewController, SensorObserver {
    private let sensorSection = Section()
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsSensors.title

        if !Current.isCatalyst {
            tableView.refreshControl = refreshControl
            refreshControl.beginRefreshing()
        }

        Current.sensors.register(observer: self)

        tableView.alwaysBounceVertical = true

        let periodicDescription: String

        if PeriodicUpdateManager.supportsBackgroundPeriodicUpdates {
            periodicDescription = L10n.SettingsSensors.PeriodicUpdate.descriptionMac
        } else {
            periodicDescription = L10n.SettingsSensors.PeriodicUpdate.description
        }

        form +++ Section(header: nil, footer: periodicDescription)
            <<< PushRow<TimeInterval?> {
                $0.title = L10n.SettingsSensors.PeriodicUpdate.title
                $0.options = {
                    var options: [TimeInterval?] = [nil, 20, 60, 120, 300, 600, 900, 1800, 3600]

                    if Current.appConfiguration == .Debug {
                        options.insert(contentsOf: [2, 5], at: 1)
                    }

                    return options
                }()
                $0.value = Current.settingsStore.periodicUpdateInterval
                $0.onChange { row in
                    // this looks silly but value is actually `Optional<Optional<TimeInterval>>`
                    Current.settingsStore.periodicUpdateInterval = row.value ?? nil
                }

                let formatter = DateComponentsFormatter()
                formatter.unitsStyle = .full

                $0.displayValueFor = { value in
                    switch value {
                    case .some(.none), .none:
                        return L10n.SettingsSensors.PeriodicUpdate.off
                    case let .some(.some(interval)):
                        return formatter.string(from: interval)
                    }
                }
            }

        let permissionRows = [
            motionPermissionRow(),
            focusPermissionRow(),
        ].compactMap { $0 }

        if !permissionRows.isEmpty {
            form +++ Section(permissionRows)
        }

        form +++ sensorSection

        refreshControl.addTarget(self, action: #selector(refresh), for: .primaryActionTriggered)
    }

    @objc private func refresh() {
        refreshControl.beginRefreshing()

        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.ensure { [refreshControl] in
            refreshControl.endRefreshing()
        }.cauterize()
    }

    private func motionPermissionRow() -> BaseRow? {
        guard Current.motion.isActivityAvailable() else {
            return nil
        }

        return MotionPermissionRow { row in
            func update(isInitial: Bool) {
                row.value = CMMotionActivityManager.authorizationStatus()

                if !isInitial {
                    row.updateCell()
                }
            }

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

    private func focusPermissionRow() -> BaseRow? {
        guard Current.focusStatus.isAvailable() else {
            return nil
        }

        return FocusPermissionRow { row in
            func update(isInitial: Bool) {
                row.value = Current.focusStatus.authorizationStatus()

                if !isInitial {
                    row.updateCell()
                }
            }

            row.title = L10n.SettingsSensors.FocusPermission.title
            update(isInitial: true)

            row.cellUpdate { cell, _ in
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }

            row.onCellSelection { _, row in
                if Current.focusStatus.authorizationStatus() == .notDetermined {
                    Current.focusStatus.requestAuthorization().done { _ in
                        update(isInitial: false)
                    }
                } else {
                    // if the user changes the value in settings, we'll be killed, so we don't need to watch anything
                    UIApplication.shared.openSettings(destination: .focus)
                }

                row.deselect(animated: true)
            }
        }
    }

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason) {
        refresh()
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        firstly {
            update.sensors
        }.map {
            $0.map { Self.row(for: $0) }
        }.ensure { [refreshControl] in
            refreshControl.endRefreshing()
        }.done { [tableView, sensorSection] value in
            let sinceFormatter = DateFormatter()
            sinceFormatter.formattingContext = .middleOfSentence
            sinceFormatter.dateStyle = .none
            sinceFormatter.timeStyle = .medium

            UIView.performWithoutAnimation {
                tableView?.beginUpdates()
                sensorSection.removeAll()
                sensorSection.append(contentsOf: value)
                sensorSection.footer = HeaderFooterView(
                    title: L10n.SettingsSensors.LastUpdated.footer(sinceFormatter.string(from: update.on))
                )
                sensorSection.reload()
                tableView?.endUpdates()
            }
        }.catch { error in
            let alert = UIAlertController(
                title: L10n.SettingsSensors.LoadingError.title,
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.retryLabel, style: .default, handler: { [weak self] _ in
                self?.refresh()
            }))
            alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: { _ in

            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    class func row(for sensor: WebhookSensor) -> BaseRow {
        ButtonRow { row in
            func updateDetails(from sensor: WebhookSensor, isInitial: Bool) {
                let isEnabled = Current.sensors.isEnabled(sensor: sensor)

                row.title = sensor.Name
                row.cellStyle = .value1

                if isEnabled {
                    row.value = sensor.StateDescription
                } else {
                    row.value = L10n.SettingsSensors.disabledStateReplacement
                }

                row.cellUpdate { cell, _ in
                    cell.detailTextLabel?.text = row.value

                    if isEnabled {
                        cell.tintColor = nil

                        if #available(iOS 13, *) {
                            cell.textLabel?.textColor = .label
                        } else {
                            cell.textLabel?.textColor = .black
                        }
                    } else {
                        if #available(iOS 13, *) {
                            cell.textLabel?.textColor = .secondaryLabel
                            cell.tintColor = .systemFill
                        } else {
                            cell.textLabel?.textColor = .darkGray
                            cell.tintColor = .lightGray
                        }
                    }

                    cell.imageView?.image =
                        sensor.Icon
                            .flatMap({ MaterialDesignIcons(serversideValueNamed: $0) })?
                            .settingsIcon(for: cell.traitCollection)
                }

                if !isInitial {
                    row.updateCell()
                }
            }

            updateDetails(from: sensor, isInitial: true)

            row.presentationMode = .show(controllerProvider: .callback(builder: {
                SensorDetailViewController(sensor: sensor)
            }), onDismiss: {
                if let controller = $0 as? SensorDetailViewController {
                    updateDetails(from: controller.sensor, isInitial: false)
                }
            })
        }
    }
}
