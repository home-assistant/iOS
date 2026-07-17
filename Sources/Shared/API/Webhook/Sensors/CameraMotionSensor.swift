import Foundation
import PromiseKit

final class CameraMotionSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler,
    MotionDetectionObserver {
    let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .cameraMotion,
        ])
    }

    func motionStateDidChange(for manager: MotionDetectionManager) {
        signal()
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        // Registering the first observer starts the capture session and unregistering
        // the last one stops it, so the camera only runs while the sensor is enabled.
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
final class CameraMotionSensor: SensorProvider {
    public enum CameraMotionError: Error, Equatable {
        case unavailable
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let manager = Current.motionDetection

        guard manager.canDetectMotion else {
            return .init(error: CameraMotionError.unavailable)
        }

        // The camera must never turn on (nor its permission prompt appear) without an
        // explicit user opt-in, so this sensor starts disabled instead of enabled-by-default.
        Current.sensors.disableInitially(sensorId: .cameraMotion)

        let isDetected = manager.isMotionDetected

        let sensor = WebhookSensor(
            name: "Camera Motion",
            uniqueID: WebhookSensorId.cameraMotion.rawValue,
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
                title: L10n.Sensors.CameraMotion.Setting.frameRate
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
                title: L10n.Sensors.CameraMotion.Setting.changedAreaThreshold
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
                title: L10n.Sensors.CameraMotion.Setting.clearDelay
            ),
        ]

        // Set up our observer (starts/stops the camera with sensor enablement)
        let _: CameraMotionSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
        #else
        return .init(error: CameraMotionError.unavailable)
        #endif
    }
}
