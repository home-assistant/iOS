import Foundation
import PromiseKit

final class ActiveSensorUpdateSignaler: SensorProviderUpdateSignaler, ActiveStateObserver, SensorObserver {
    /// Indicates where observation is already happening
    private var isObserving = false
    /// Indicates where intial sensors update is going to happen
    private var firstUpdate = true

    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
        Current.sensors.register(observer: self)
    }

    func activeStateDidChange(for manager: ActiveStateManager) {
        signal()
    }

    private func observe() {
        guard !isObserving else { return }
        Current.activeState.register(observer: self)
        isObserving = true
    }

    private func stopObserving() {
        guard isObserving else { return }
        Current.activeState.unregister(observer: self)
        isObserving = false
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
                sensor.UniqueID == WebhookSensorId.active.rawValue
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

final class ActiveSensor: SensorProvider {
    public enum ActiveError: Error, Equatable {
        case noActiveState
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        let activeState = Current.activeState

        guard activeState.canTrackActiveStatus else {
            return .init(error: ActiveError.noActiveState)
        }

        let isActive = activeState.isActive

        let sensor = WebhookSensor(
            name: "Active",
            uniqueID: WebhookSensorId.active.rawValue,
            icon: isActive ? "mdi:monitor" : "mdi:monitor-off",
            state: isActive
        )
        sensor.Type = "binary_sensor"
        sensor.Attributes = activeState.states.attributes

        let durationFormatter = with(DateComponentsFormatter()) {
            $0.allowedUnits = [.minute, .second]
            $0.allowsFractionalUnits = true
            $0.formattingContext = .standalone
            $0.unitsStyle = .short
        }

        sensor.Settings = [
            .init(
                type: .stepper(
                    getter: { activeState.minimumIdleTime.converted(to: .minutes).value },
                    setter: { activeState.minimumIdleTime = .init(value: $0, unit: .minutes) },
                    minimum: 0.25,
                    maximum: .greatestFiniteMagnitude,
                    step: 0.25,
                    displayValueFor: { value in
                        let valueMeasurement = Measurement<UnitDuration>(value: value ?? 0, unit: .minutes)
                        return durationFormatter.string(from: valueMeasurement.converted(to: .seconds).value)
                    }
                ),
                title: L10n.Sensors.Active.Setting.timeUntilIdle
            ),
        ]

        // Set up our observer
        let _: ActiveSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
    }
}
