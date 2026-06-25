import AVFoundation
import Foundation
import PromiseKit

final class KioskVolumeSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var observation: NSKeyValueObservation?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .kioskVolume,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Observe the shared session's output volume. Reading the value is always accurate; live
        // notifications are best-effort and we intentionally avoid activating the session so we
        // don't interrupt any audio the user (or Home Assistant) may be playing.
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            self?.signal()
        }
        #endif
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        observation?.invalidate()
        observation = nil
        isObserving = false
    }
}

/// Reports the device output volume as a number between 0 and 100. iOS/iPadOS only.
final class KioskVolumeSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let volume = Int((AVAudioSession.sharedInstance().outputVolume * 100).rounded())
        sensors.append(WebhookSensor(
            name: "Kiosk Volume",
            uniqueID: WebhookSensorId.kioskVolume.rawValue,
            icon: "mdi:volume-high",
            state: volume
        ))

        // Set up our observer for volume changes
        let _: KioskVolumeSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)
        #endif
        return .value(sensors)
    }
}
