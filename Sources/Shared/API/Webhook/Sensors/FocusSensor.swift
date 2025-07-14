import Foundation
import HAKit
import PromiseKit

final class FocusSensorUpdateSignaler: SensorProviderUpdateSignaler, SensorObserver {
    private var isObserving = false
    var cancellable: HACancellable?
    private let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
    }

    deinit {
        cancellable?.cancel()
    }

    private func observe() {
        guard !isObserving else { return }
        cancellable = Current.focusStatus.trigger.observe { [weak self] _ in
            // this means that we will double-update the focus sensor if the app is running
            // this feels less likely to happen, but allows us to keep the in-app visual state right
            if Current.isForegroundApp() {
                self?.signal()
            }
        }
        isObserving = true
    }

    private func stopObserving() {
        guard isObserving else { return }
        cancellable?.cancel()
        isObserving = false
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors.done { [weak self] sensors in
            let activeRelatedSensors = sensors.filter({ sensor in
                sensor.UniqueID == WebhookSensorId.focus.rawValue
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

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason) {
        /* no-op */
    }
}

final class FocusSensor: SensorProvider {
    public enum FocusError: Error, Equatable {
        case unauthorized
        case unavailable
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard Current.focusStatus.isAvailable() else {
            return .init(error: FocusError.unavailable)
        }

        guard Current.focusStatus.authorizationStatus() == .authorized else {
            return .init(error: FocusError.unauthorized)
        }

        let focusState = Current.focusStatus.status()
        var sensors = [WebhookSensor]()

        if let isFocused = focusState.isFocused {
            sensors.append(with(WebhookSensor(
                name: "Focus",
                uniqueID: WebhookSensorId.focus.rawValue,
                icon: "mdi:moon-waning-crescent",
                state: isFocused
            )) {
                $0.Type = "binary_sensor"
            })
        }

        // Set up our observer
        let _: FocusSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value(sensors)
    }
}
