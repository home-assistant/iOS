import AVFoundation
import Combine
import Foundation
import PromiseKit

final class KioskVolumeSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var observation: NSKeyValueObservation?
    private var cancellable: AnyCancellable?
    private let volumeChanges = PassthroughSubject<Void, Never>()
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
        // `outputVolume` only emits KVO changes while the app's audio session is active, so activate
        // a non-intrusive ambient session that mixes with other audio purely to receive volume
        // change callbacks. It's deactivated again in `stopObserving()` when the sensor is disabled.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        // Holding the volume buttons fires many KVO changes in quick succession; debounce so we send a
        // single sensor update once the volume settles, instead of a burst of webhooks.
        cancellable = volumeChanges
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.signal()
            }
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            self?.volumeChanges.send()
        }
        #endif
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        observation?.invalidate()
        observation = nil
        cancellable?.cancel()
        cancellable = nil
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Release the audio session we activated for volume observation, letting other audio resume.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        isObserving = false
    }
}

/// Reports the device output volume as a percentage. Enabled only while kiosk mode is enabled, iOS/iPadOS only.
final class KioskVolumeSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let volume = Int((AVAudioSession.sharedInstance().outputVolume * 100).rounded())
        sensors.append(with(WebhookSensor(
            name: "Kiosk Volume",
            uniqueID: WebhookSensorId.kioskVolume.rawValue,
            icon: "mdi:volume-high",
            state: volume
        )) {
            $0.UnitOfMeasurement = "%"
        })

        // Set up our observer for volume changes
        let _: KioskVolumeSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)
        #endif
        return .value(sensors)
    }
}
