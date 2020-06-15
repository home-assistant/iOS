import Foundation
import Shared
import Eureka
import UIKit

class SensorDetailViewController: FormViewController {
    private(set) var sensor: WebhookSensor

    init(sensor: WebhookSensor) {
        self.sensor = sensor
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateModels()
    }

    private func updateModels() {
        title = sensor.Name

        form.removeAll()

        let baseSection = Section()
        baseSection <<< LabelRow {
            $0.title = L10n.SettingsSensors.Detail.uniqueId
            $0.value = sensor.UniqueID
        }
        baseSection <<< LabelRow {
            $0.title = L10n.SettingsSensors.Detail.state
            $0.value = sensor.StateDescription
        }

        if let deviceClass = sensor.DeviceClass {
            baseSection <<< LabelRow {
                $0.title = L10n.SettingsSensors.Detail.deviceClass
                $0.value = deviceClass.rawValue
            }
        }

        if let icon = sensor.Icon {
            baseSection <<< LabelRow {
                $0.title = L10n.SettingsSensors.Detail.icon
                $0.value = icon
            }
        }

        form +++ baseSection

        if let attributes = sensor.Attributes {
            let attributesSection = Section(header: L10n.SettingsSensors.Detail.attributes, footer: nil)
            let attributeRows = attributes
                .sorted(by: { lhs, rhs in lhs.0 < rhs.0 })
                .map(Self.row(attribute:value:))
            attributesSection.append(contentsOf: attributeRows)
            form.append(attributesSection)
        }
    }

    class func row(attribute: String, value: Any) -> BaseRow {
        return LabelRow { row in
            row.title = attribute
            row.value = String(describing: value)
        }
    }
}
