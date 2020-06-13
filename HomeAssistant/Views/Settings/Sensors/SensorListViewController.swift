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
