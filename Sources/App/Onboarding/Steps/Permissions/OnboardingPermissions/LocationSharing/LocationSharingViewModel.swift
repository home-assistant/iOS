import CoreLocation
import Foundation
import Shared

final class LocationSharingViewModel: NSObject, ObservableObject {
    @Published var showDenyAlert: Bool = false
    @Published var shouldComplete: Bool = false
    private var webhookSensors: [WebhookSensor] = []

    private let sensorIdsToEnableDisable: [WebhookSensorId] = [
        .geocodedLocation,
        .connectivityBSID,
        .connectivitySSID,
    ]

    override init() {
        super.init()
        Current.sensors.register(observer: self)
    }

    func disableLocationSensor() {
        for sensor in locationRelatedSensors() {
            Current.sensors.setEnabled(false, for: sensor)
        }
    }

    func enableLocationSensor() {
        for sensor in locationRelatedSensors() {
            Current.sensors.setEnabled(true, for: sensor)
        }
    }

    private func locationRelatedSensors() -> [WebhookSensor] {
        webhookSensors.filter { sensor in
            sensorIdsToEnableDisable.map(\.rawValue).contains(sensor.UniqueID)
        }
    }
}

extension LocationSharingViewModel: SensorObserver {
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        /* no-op */
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors.done { [weak self] sensors in
            self?.webhookSensors = sensors
        }
    }
}
