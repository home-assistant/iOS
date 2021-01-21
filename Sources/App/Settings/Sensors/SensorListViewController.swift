import Foundation
import Eureka
import Shared
import PromiseKit

class SensorListViewController: FormViewController, SensorObserver {
    private let sensorSection = Section()
    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsSensors.title

        tableView.refreshControl = refreshControl
        refreshControl.beginRefreshing()

        Current.sensors.register(observer: self)

        tableView.alwaysBounceVertical = true

        let periodicDescription: String

        if LifecycleManager.supportsBackgroundPeriodicUpdates {
            periodicDescription = L10n.SettingsSensors.PeriodicUpdate.descriptionMac
        } else {
            periodicDescription = L10n.SettingsSensors.PeriodicUpdate.description
        }

        form +++ Section(header: nil, footer: periodicDescription)
        <<< PushRow<TimeInterval?> {
            $0.title =  L10n.SettingsSensors.PeriodicUpdate.title
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
                case .some(.some(let interval)):
                    return formatter.string(from: interval)
                }
            }
        }

        form +++ sensorSection

        refreshControl.addTarget(self, action: #selector(refresh), for: .primaryActionTriggered)
    }

    @objc private func refresh() {
        refreshControl.beginRefreshing()

        Current.backgroundTask(withName: "manual-location-update-settings") { _ in
            Current.api.then { api -> Promise<Void> in
                if Current.settingsStore.isLocationEnabled(for: UIApplication.shared.applicationState) {
                    return api.GetAndSendLocation(trigger: .Manual).asVoid()
                } else {
                    return api.UpdateSensors(trigger: .Manual).asVoid()
                }
            }
        }.ensure { [refreshControl] in
            refreshControl.endRefreshing()
        }.cauterize()
    }

    func sensorContainerDidSignalForUpdate(
        _ container: SensorContainer
    ) {
        // we don't do anything for this
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

            tableView?.beginUpdates()
            sensorSection.removeAll()
            sensorSection.append(contentsOf: value)
            sensorSection.footer = HeaderFooterView(
                title: L10n.SettingsSensors.LastUpdated.footer(sinceFormatter.string(from: update.on))
            )
            sensorSection.reload()
            tableView?.endUpdates()
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
        return ButtonRow { row in
            func updateDetails(from sensor: WebhookSensor, isInitial: Bool) {
                row.title = sensor.Name
                row.value = sensor.StateDescription
                row.cellStyle = .value1

                row.cellUpdate { cell, _ in
                    cell.detailTextLabel?.text = row.value

                    cell.imageView?.image =
                        sensor.Icon
                            .flatMap({ MaterialDesignIcons(serversideValueNamed: $0) })?
                            .image(ofSize: CGSize(width: 28, height: 28), color: .black)
                            .withRenderingMode(.alwaysTemplate)
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
