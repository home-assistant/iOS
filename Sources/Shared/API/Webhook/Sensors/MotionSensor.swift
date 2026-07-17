import Foundation
import PromiseKit

// Target location in repo: Sources/Shared/API/Webhook/Sensors/MotionSensor.swift

final class MotionSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler,
    MotionDetectionObserver {
    let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .motion,
        ])
    }

    func motionStateDidChange(for manager: MotionDetectionManager) {
        signal()
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        // Registering starts the capture session (first observer); unregistering
        // stops it (last observer). The camera therefore only runs while the
        // sensor is enabled.
        Current.motionDetection.register(observer: self)
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        Current.motionDetection.unregister(observer: self)
        isObserving = false
    }
}

/// Reports motion detected by the device's front camera using frame differencing.
/// Intended for kiosk/wall-mounted devices: capture only works while the app is
/// in the foreground. iOS/iPadOS only.
final class MotionSensor: SensorProvider {
    public enum MotionError: Error, Equatable {
        case unavailable
    }

    private enum UserDefaultsKeys: String {
        case initialized = "motion_sensor_initialized"
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let manager = Current.motionDetection

        guard manager.canDetectMotion else {
            return .init(error: MotionError.unavailable)
        }

        disableOnFirstRun()

        let isDetected = manager.isMotionDetected

        let sensor = WebhookSensor(
            name: "Camera Motion",
            uniqueID: WebhookSensorId.motion.rawValue,
            icon: isDetected ? "mdi:motion-sensor" : "mdi:motion-sensor-off",
            deviceClass: .motion,
            state: isDetected
        )
        sensor.Type = "binary_sensor"
        sensor.Attributes = manager.attributes

        sensor.Settings = [
            .init(
                type: .stepper(
                    getter: { manager.frameRate },
                    setter: { manager.frameRate = $0 },
                    minimum: 1,
                    maximum: 30,
                    step: 1,
                    displayValueFor: { value in
                        value.map { String(format: "%.0f fps", $0) }
                    }
                ),
                title: L10n.Sensors.Motion.Setting.frameRate
            ),
            .init(
                type: .stepper(
                    getter: { manager.areaThresholdPercent },
                    setter: { manager.areaThresholdPercent = $0 },
                    minimum: 0.5,
                    maximum: 25,
                    step: 0.5,
                    displayValueFor: { value in
                        value.map { String(format: "%.1f %%", $0) }
                    }
                ),
                title: L10n.Sensors.Motion.Setting.changedAreaThreshold
            ),
            .init(
                type: .stepper(
                    getter: { manager.clearDelay },
                    setter: { manager.clearDelay = $0 },
                    minimum: 5,
                    maximum: 300,
                    step: 5,
                    displayValueFor: { value in
                        value.map { String(format: "%.0f s", $0) }
                    }
                ),
                title: L10n.Sensors.Motion.Setting.clearDelay
            ),
        ]

        // Set up our observer (starts/stops the camera with sensor enablement)
        let _: MotionSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
        #else
        return .init(error: MotionError.unavailable)
        #endif
    }

    /// Sensors are enabled by default, but the camera must never turn on (nor the
    /// permission prompt appear) without an explicit user opt-in — so unlike other
    /// sensors, this one starts disabled.
    private func disableOnFirstRun() {
        let prefs = Current.settingsStore.prefs
        guard prefs.object(forKey: UserDefaultsKeys.initialized.rawValue) == nil else { return }
        prefs.set(true, forKey: UserDefaultsKeys.initialized.rawValue)
        Current.sensors.setEnabled(false, forUniqueID: WebhookSensorId.motion.rawValue)
    }
}
