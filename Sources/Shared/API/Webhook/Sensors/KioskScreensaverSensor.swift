import Combine
import Foundation
import PromiseKit

final class KioskScreensaverSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var cancellable: AnyCancellable?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .kioskScreensaver,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        cancellable = Current.kiosk.screensaverVisiblePublisher
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

/// Reports whether the kiosk screensaver is currently visible: on while the screensaver is on screen,
/// off otherwise. Enabled only while kiosk mode is enabled, iOS/iPadOS only.
final class KioskScreensaverSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let isVisible = Current.kiosk.isScreensaverVisible
        let sensor = WebhookSensor(
            name: "Kiosk Screensaver",
            uniqueID: WebhookSensorId.kioskScreensaver.rawValue,
            icon: isVisible ? "mdi:sleep" : "mdi:sleep-off",
            state: isVisible
        )
        sensor.Type = "binary_sensor"
        sensors.append(sensor)

        // Set up our observer for screensaver visibility changes
        let _: KioskScreensaverSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)
        #endif
        return .value(sensors)
    }
}
