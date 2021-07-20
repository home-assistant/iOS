import Eureka
import Foundation
import Shared
import UIKit

class SensorDetailViewController: HAFormViewController, SensorObserver {
    private(set) var sensor: WebhookSensor {
        didSet {
            if oldValue != sensor {
                UIView.performWithoutAnimation {
                    updateModels()
                }
            }
        }
    }

    init(sensor: WebhookSensor) {
        self.sensor = sensor

        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Current.sensors.register(observer: self)

        if form.isEmpty {
            updateModels()
        }
    }

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason) {
        // we don't care about when updates are going to happen
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors
            .firstValue(where: { [sensor] each in each.UniqueID == sensor.UniqueID })
            .done { [self] updated in
                sensor = updated
            }.catch { _ in
                Current.Log.info("saw a sensor update that didn't include our sensor")
            }
    }

    private func updateModels() {
        title = sensor.Name

        form.removeAll()

        let baseSection = Section()

        baseSection <<< SwitchRow {
            $0.title = L10n.SettingsSensors.Detail.enabled
            $0.value = Current.sensors.isEnabled(sensor: sensor)
            $0.onChange { [sensor] row in
                Current.sensors.setEnabled(row.value ?? true, for: sensor)
            }
        }

        if Current.sensors.isEnabled(sensor: sensor) {
            baseSection <<< LabelRow {
                $0.title = L10n.SettingsSensors.Detail.state
                $0.value = sensor.StateDescription
            }
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
            case let .switch(getter, setter):
                return SwitchRow {
                    $0.title = setting.title
                    $0.value = getter()
                    $0.onChange { row in
                        setter(row.value ?? false)
                    }
                }
            case let .stepper(getter, setter, minimum, maximum, step, displayValueFor):
                if #available(iOS 14, *), UIDevice.current.userInterfaceIdiom == .mac {
                    return DecimalRow {
                        $0.title = setting.title
                        $0.value = getter()
                        $0.onChange { row in
                            if let value = row.value {
                                if value < minimum {
                                    row.value = minimum
                                }

                                if value > maximum {
                                    row.value = maximum
                                }

                                let updated = (value / step).rounded(.down) * step
                                if abs(updated - value) > 0.05 {
                                    row.value = updated
                                }
                            }

                            setter(row.value ?? 0)
                        }

                        if let displayValueFor = displayValueFor {
                            $0.displayValueFor = displayValueFor
                        }
                    }
                } else {
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
            }
        })

        return section
    }

    class func row(attribute: String, value: Any) -> BaseRow {
        LabelRow { row in
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
