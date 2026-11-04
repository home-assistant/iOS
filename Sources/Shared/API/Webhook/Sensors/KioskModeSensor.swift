import Combine
import Foundation
import PromiseKit

final class KioskModeSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var cancellable: AnyCancellable?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .kioskMode,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        cancellable = Current.kiosk.settingsPublisher
            .map(\.enabled)
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.signal()
            }
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        cancellable?.cancel()
        cancellable = nil
        isObserving = false
    }
}

/// Reports whether the app is currently running in kiosk mode. iOS/iPadOS only.
final class KioskModeSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let isEnabled = Current.kioskSettings.enabled
        let sensor = WebhookSensor(
            name: "Kiosk Mode",
            uniqueID: WebhookSensorId.kioskMode.rawValue,
            icon: isEnabled ? "mdi:tablet-dashboard" : "mdi:tablet",
            state: isEnabled
        )
        sensor.Type = "binary_sensor"
        sensors.append(sensor)

        // Set up our observer for kiosk mode changes
        let _: KioskModeSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)
        #endif
        return .value(sensors)
    }
}
