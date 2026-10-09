import Foundation
import PromiseKit

final class DevicePoseSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
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
            return .value([HingeSensor.unreadSensor(named: "Pose", id: .devicePose)])
        }

        return .value([Self.sensor(for: pose)])
        #else
        return .init(error: HingeSensor.HingeError.unsupported)
        #endif
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
