import Combine
import Foundation
import Shared
import SwiftUI
import UIKit

class SensorDetailViewModel: ObservableObject, SensorObserver {
    @Published private(set) var sensor: WebhookSensor
    @Published var isEnabled: Bool
    @Published var stateDescription: String?
    @Published var deviceClass: String?
    @Published var icon: String?
    @Published var settingsViews: [AnyView] = []
    @Published var attributes: [(key: String, value: Any)] = []

    private var cancellables = Set<AnyCancellable>()

    init(sensor: WebhookSensor) {
        self.sensor = sensor
        self.isEnabled = Current.sensors.isEnabled(sensor: sensor)
        self.stateDescription = sensor.StateDescription
        self.deviceClass = sensor.DeviceClass?.rawValue
        self.icon = sensor.Icon
        self.attributes = sensor.Attributes?.sorted(by: { $0.0 < $1.0 }) ?? []

        updateSettingsViews()

        Current.sensors.register(observer: self)
    }

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason) {
        // we don't care about when updates are going to happen
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors
            .firstValue(where: { [sensor] each in each.UniqueID == sensor.UniqueID })
            .done { [weak self] updated in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.sensor = updated
                    self.isEnabled = Current.sensors.isEnabled(sensor: updated)
                    self.stateDescription = updated.StateDescription
                    self.deviceClass = updated.DeviceClass?.rawValue
                    self.icon = updated.Icon
                    self.attributes = updated.Attributes?.sorted(by: { $0.0 < $1.0 }) ?? []
                    self.updateSettingsViews()
                }
            }.catch { _ in
                Current.Log.info("saw a sensor update that didn't include our sensor")
            }
    }

    func setEnabled(_ enabled: Bool) {
        Current.sensors.setEnabled(enabled, for: sensor)
        isEnabled = enabled
    }

    private func updateSettingsViews() {
        guard sensor.Settings.isEmpty == false else {
            settingsViews = []
            return
        }
        settingsViews = SensorDetailView.settingsSection(from: sensor.Settings)
    }
}
