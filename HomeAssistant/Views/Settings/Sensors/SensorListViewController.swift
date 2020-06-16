import Foundation
import Eureka
import Shared
import Iconic
import PromiseKit

class SensorListViewController: FormViewController {
    private let sensorSection = Section()
    private let refreshControl = UIRefreshControl()
    private let sensors = WebhookSensors()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsSensors.title

        updateSensors(section: sensorSection)
        form +++ Section(header: nil, footer: L10n.SettingsSensors.PeriodicUpdate.description)
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

        tableView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(refresh), for: .primaryActionTriggered)
    }

    @objc private func refresh() {
        updateSensors(section: sensorSection)
    }

    private func updateSensors(section: Section) {
        guard !refreshControl.isRefreshing else { return }

        refreshControl.beginRefreshing()

        firstly {
            sensors.AllSensors
        }.map {
            $0.map { Self.row(for: $0) }
        }.done {
            section.removeAll()
            section.append(contentsOf: $0)
        }.ensure { [refreshControl] in
            refreshControl.endRefreshing()
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
                            .flatMap(MaterialDesignIcons.init(named:))?
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
