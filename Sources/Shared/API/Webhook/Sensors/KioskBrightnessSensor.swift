import Combine
import Foundation
import PromiseKit
#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
#endif

final class KioskBrightnessSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var cancellable: AnyCancellable?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .kioskBrightness,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Control Center / hardware changes can fire many notifications in quick succession; debounce so
        // we send a single sensor update once the brightness settles, instead of a burst of webhooks.
        cancellable = NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.signal()
            }
        #endif
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

/// Reports the current screen brightness as a percentage. Enabled only while kiosk mode is enabled, iOS/iPadOS only.
final class KioskBrightnessSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let brightness = Int((Current.screenBrightness() * 100).rounded())
        sensors.append(with(WebhookSensor(
            name: "Kiosk Brightness",
            uniqueID: WebhookSensorId.kioskBrightness.rawValue,
            icon: "mdi:brightness-6",
            state: brightness
        )) {
            $0.UnitOfMeasurement = "%"
        })

        // Set up our observer for brightness changes
        let _: KioskBrightnessSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)
        #endif
        return .value(sensors)
    }
}
