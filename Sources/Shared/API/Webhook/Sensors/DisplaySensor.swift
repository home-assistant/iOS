import Foundation
import PromiseKit

final class DisplaySensorUpdateSignaler: SensorProviderUpdateSignaler, SensorObserver {
    static var notificationName: Notification.Name {
        #if targetEnvironment(macCatalyst)
        return Current.macBridge.screensWillChangeNotification
        #else
        return .init(rawValue: "test_screensWillChangeNotification")
        #endif
    }

    /// Indicates where observation is already happening
    private var isObserving = false
    /// Indicates where intial sensors update is going to happen
    private var firstUpdate = true

    #if DEBUG
    /// Used for unit test to identify when observation is ready
    var notifyObservation: (() -> Void)?
    #endif

    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
        Current.sensors.register(observer: self)
    }

    @objc private func screensDidChange(_ note: Notification) {
        signal()
    }

    private func observe() {
        guard !isObserving else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange(_:)),
            name: Self.notificationName,
            object: nil
        )
        isObserving = true
        #if DEBUG
        notifyObservation?()
        #endif
    }

    private func stopObserving() {
        guard isObserving else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: Self.notificationName,
            object: nil
        )
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
                sensor.UniqueID == WebhookSensorId.displaysCount.rawValue ||
                    sensor.UniqueID == WebhookSensorId.primaryDisplayName.rawValue ||
                    sensor.UniqueID == WebhookSensorId.primaryDisplayId.rawValue
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

final class DisplaySensor: SensorProvider {
    public enum DisplayError: Error, Equatable {
        case unsupportedPlatform
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard let screens = Current.device.screens() else {
            return .init(error: DisplayError.unsupportedPlatform)
        }

        var sensors = [WebhookSensor]()

        sensors.append(with(WebhookSensor(
            name: "Displays",
            uniqueID: WebhookSensorId.displaysCount.rawValue,
            icon: "mdi:monitor-multiple",
            state: screens.count
        )) {
            $0.Attributes = [
                "Display IDs": screens.map(\.identifier),
                "Display Names": screens.map(\.name),
            ]
        })

        sensors.append(WebhookSensor(
            name: "Primary Display Name",
            uniqueID: WebhookSensorId.primaryDisplayName.rawValue,
            icon: "mdi:monitor-star",
            state: screens.first.map(\.name) ?? "None"
        ))

        sensors.append(WebhookSensor(
            name: "Primary Display ID",
            uniqueID: WebhookSensorId.primaryDisplayId.rawValue,
            icon: "mdi:monitor-star",
            state: screens.first.map(\.identifier) ?? "None"
        ))

        // Set up our observer
        let _: DisplaySensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value(sensors)
    }
}
