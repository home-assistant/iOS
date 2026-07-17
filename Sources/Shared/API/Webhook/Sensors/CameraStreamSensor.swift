import Foundation
import PromiseKit

final class CameraStreamSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .cameraStream,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        // Enabling the sensor turns the stream server on: the listener starts and
        // the camera runs continuously (foreground only) so the stream is instantly
        // available to clients.
        Current.cameraStreamServer.onStateChange = { [weak self] in
            self?.signal()
        }
        Current.cameraStreamServer.setActive(true)
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        Current.cameraStreamServer.onStateChange = nil
        Current.cameraStreamServer.setActive(false)
        isObserving = false
    }
}

/// Exposes the MJPEG camera stream server as a sensor: enabling it starts the server
/// (and the camera), the state reports whether a client is currently pulling the
/// stream. Consumed in Home Assistant through the MJPEG camera integration pointed
/// at `http://<device-ip>:<port>/`. iOS/iPadOS only.
final class CameraStreamSensor: SensorProvider {
    public enum CameraStreamError: Error, Equatable {
        case unavailable
    }

    private enum UserDefaultsKeys: String {
        case initialized = "camera_stream_sensor_initialized"
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard Current.motionDetection.canDetectMotion else {
            return .init(error: CameraStreamError.unavailable)
        }

        disableOnFirstRun()

        let server = Current.cameraStreamServer
        let isStreaming = server.isStreaming

        let sensor = WebhookSensor(
            name: "Camera Stream",
            uniqueID: WebhookSensorId.cameraStream.rawValue,
            icon: isStreaming ? "mdi:cctv" : "mdi:cctv-off",
            state: isStreaming ? "streaming" : "idle"
        )
        sensor.Attributes = [
            "Port": Int(server.port),
            "Clients": server.clientCount,
            "Stream URL": server.streamURL ?? "unavailable (no Wi-Fi address)",
        ]

        sensor.Settings = [
            .init(
                type: .stepper(
                    getter: { server.port },
                    setter: { server.port = $0 },
                    minimum: 1024,
                    maximum: 65535,
                    step: 1,
                    displayValueFor: { value in
                        value.map { String(Int($0)) }
                    }
                ),
                title: L10n.Sensors.CameraStream.Setting.streamPort
            ),
        ]

        // Set up our observer (starts/stops the server with sensor enablement)
        let _: CameraStreamSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
        #else
        return .init(error: CameraStreamError.unavailable)
        #endif
    }

    /// Sensors are enabled by default, but the camera must never turn on without an
    /// explicit user opt-in — so unlike other sensors, this one starts disabled.
    private func disableOnFirstRun() {
        let prefs = Current.settingsStore.prefs
        guard prefs.object(forKey: UserDefaultsKeys.initialized.rawValue) == nil else { return }
        prefs.set(true, forKey: UserDefaultsKeys.initialized.rawValue)
        Current.sensors.setEnabled(false, forUniqueID: WebhookSensorId.cameraStream.rawValue)
    }
}
