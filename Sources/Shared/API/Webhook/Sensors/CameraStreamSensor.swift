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

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard Current.motionDetection.canDetectMotion else {
            return .init(error: CameraStreamError.unavailable)
        }

        // The camera must never turn on (nor its permission prompt appear) without an
        // explicit user opt-in, so this sensor starts disabled instead of enabled-by-default.
        Current.sensors.disableInitially(sensorId: .cameraStream)

        let server = Current.cameraStreamServer
        let isStreaming = server.isStreaming

        let sensor = WebhookSensor(
            name: "Camera Stream",
            uniqueID: WebhookSensorId.cameraStream.rawValue,
            icon: isStreaming ? "mdi:cctv" : "mdi:cctv-off",
            state: isStreaming ? "streaming" : "idle"
        )
        sensor.Attributes = [
            "Port": server.port,
            "Clients": server.clientCount,
            "Stream URL": server.streamURL ?? "unavailable (no Wi-Fi address)",
        ]

        sensor.Settings = [
            .init(
                type: .stepper(
                    getter: { Double(server.port) },
                    setter: { server.port = Int($0) },
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
}
