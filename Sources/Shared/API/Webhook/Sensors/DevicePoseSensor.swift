import Foundation
import PromiseKit

public final class DevicePoseSensor: SensorProvider {
    public let request: SensorProviderRequest
    public init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let observer = Current.hinge

        guard observer.isSupported else {
            return .init(error: HingeSensor.HingeError.unsupported)
        }

        if observer.hasReceivedUpdate, observer.state == nil {
            return .init(error: HingeSensor.HingeError.unsupported)
        }

        let _: DevicePoseSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        guard let pose = observer.pose else {
            return .value([Self.unreadSensor()])
        }

        return .value([Self.sensor(for: pose)])
        #else
        return .init(error: HingeSensor.HingeError.unsupported)
        #endif
    }

    /// The pose sensor as it stands before anything has read the hinge. Also what the sensors list
    /// shows for it on a device without one, which never reads a hinge at all.
    public static func unreadSensor() -> WebhookSensor {
        HingeSensor.unreadSensor(named: "Pose", id: .devicePose)
    }

    static func sensor(for pose: DevicePose) -> WebhookSensor {
        WebhookSensor(
            name: "Pose",
            uniqueID: WebhookSensorId.devicePose.rawValue,
            icon: pose.icon,
            state: pose.rawValue
        )
    }
}

private extension DevicePose {
    var icon: String {
        switch self {
        case .unknown:
            return "mdi:cellphone-remove"
        case .closed:
            return "mdi:cellphone"
        case .book:
            return "mdi:book-open-variant"
        case .laptop:
            return "mdi:laptop"
        case .partiallyOpen:
            return "mdi:book-open-outline"
        case .flat:
            return "mdi:tablet"
        case .flatFaceDown:
            return "mdi:flip-vertical"
        }
    }
}
