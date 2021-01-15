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

        if sensor.Settings.isEmpty == false {
            form.append(Self.settingsSection(from: sensor.Settings))
        }

        if let attributes = sensor.Attributes, !attributes.isEmpty {
            let attributesSection = Section(header: L10n.SettingsSensors.Detail.attributes, footer: nil)
            let attributeRows = attributes
                .sorted(by: { lhs, rhs in lhs.0 < rhs.0 })
                .map(Self.row(attribute:value:))
            attributesSection.append(contentsOf: attributeRows)
            form.append(attributesSection)
        }
    }

    class func settingsSection(from settings: [WebhookSensorSetting]) -> Section {
        let section = Section(
            header: L10n.SettingsSensors.Settings.header,
            footer: L10n.SettingsSensors.Settings.footer
        )

        section.append(contentsOf: settings.map { setting -> BaseRow in
            switch setting.type {
            case .switch(let getter, let setter):
                return SwitchRow {
                    $0.title = setting.title
                    $0.value = getter()
                    $0.onChange { row in
                        setter(row.value ?? false)
                    }
                }
            case .stepper(let getter, let setter, let minimum, let maximum, let step, let displayValueFor):
                return StepperRow {
                    $0.title = setting.title
                    $0.value = getter()
                    $0.onChange { row in
                        setter(row.value ?? 0)
                    }

                    if let displayValueFor = displayValueFor {
                        $0.displayValueFor = displayValueFor
                    }

                    $0.cellSetup { cell, _ in
                        with(cell.stepper) {
                            $0?.minimumValue = minimum
                            $0?.maximumValue = maximum
                            $0?.stepValue = step
                        }
                    }
                }
            }
        })

        return section
    }

    class func row(attribute: String, value: Any) -> BaseRow {
        return LabelRow { row in
            row.title = attribute

            if let value = value as? NSNumber, value === kCFBooleanTrue || value === kCFBooleanFalse {
                // boolean from objective-c is represented by NSNumber, which would normally be `0` or `1` here
                row.value = String(describing: value.boolValue)
            } else {
                row.value = String(describing: value)
            }
        }
    }
}
