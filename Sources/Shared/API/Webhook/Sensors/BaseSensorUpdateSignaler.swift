import Foundation

class BaseSensorUpdateSignaler: SensorObserver {
    /// Indicates where observation is already happening
    var isObserving = false
    /// Indicates where intial sensors update is going to happen
    var firstUpdate = true
    #if DEBUG
    /// Used for unit test to identify when observation is ready
    var notifyObservation: (() -> Void)?
    #endif

    private let relatedSensorsIds: [WebhookSensorId]

    init(relatedSensorsIds: [WebhookSensorId]) {
        self.relatedSensorsIds = relatedSensorsIds
        Current.sensors.register(observer: self)
    }

    deinit {
        Current.sensors.unregister(observer: self)
    }

    func observe() {
        /* Operation should be implemented by who inherits */
    }

    func stopObserving() {
        /* Operation should be implemented by who inherits */
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        guard firstUpdate else { return }
        firstUpdate = false
        updateObservation(sensorUpdates: update)
    }

    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        guard reason == .settingsChange else { return }
        updateObservation(sensorUpdates: lastUpdate)
    }

    private func updateObservation(sensorUpdates: SensorObserverUpdate?) {
        sensorUpdates?.sensors.done { [weak self] sensors in
            let activeRelatedSensors = sensors.filter({ sensor in
                guard let sensorId = WebhookSensorId(rawValue: sensor.UniqueID ?? "") else { return false }
                return self?.relatedSensorsIds.contains(sensorId) ?? false
            })

            let activeSensors = activeRelatedSensors.filter({ sensor in
                Current.sensors.isEnabled(sensor: sensor)
            })

            if activeSensors.isEmpty {
                self?.stopObserving()
            } else {
                self?.observe()
            }
        }
    }
}
