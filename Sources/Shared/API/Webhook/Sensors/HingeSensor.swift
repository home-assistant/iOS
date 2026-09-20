import Combine
import Foundation
import PromiseKit

final class HingeSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var cancellable: AnyCancellable?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .hingeAngle,
            .hingeStatus,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        cancellable = Current.hinge.statePublisher
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

/// Reports the angle of a folding device's hinge and how far open the system considers it.
///
/// iPhone Duo only: `Current.hinge` is fed by a `UIHingeInteraction` the app attaches to its root
/// view, so a device without a hinge answers that it has none as soon as the interaction is
/// attached, and nothing arrives at all while the app is off screen.
final class HingeSensor: SensorProvider {
    public enum HingeError: Error, Equatable {
        /// This device can never report a hinge: it has none, or it predates the API.
        case unsupported
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let observer = Current.hinge

        guard observer.isSupported else {
            return .init(error: HingeError.unsupported)
        }

        // A device that answered about its hinge and reported none has no hinge, so the sensor is
        // dropped rather than left permanently unavailable on every iPhone that does not fold.
        if observer.hasReceivedUpdate, observer.state == nil {
            return .init(error: HingeError.unsupported)
        }

        // Set up our observer for hinge changes
        let _: HingeSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        guard let state = observer.state else {
            // Nothing has observed the hinge yet this launch. The sensors stay listed, reporting
            // that they have no reading, so their rows remain available to switch on.
            return .value([
                Self.unreadSensor(named: "Hinge Angle", id: .hingeAngle),
                Self.unreadSensor(named: "Hinge Status", id: .hingeStatus),
            ])
        }

        return .value([
            Self.angleSensor(for: state),
            Self.statusSensor(for: state),
        ])
        #else
        return .init(error: HingeError.unsupported)
        #endif
    }

    /// A sensor the app knows but has no reading for yet, reported as explicitly unavailable so
    /// the row that switches it on stays in the list.
    static func unreadSensor(named name: String, id: WebhookSensorId) -> WebhookSensor {
        WebhookSensor(
            name: name,
            uniqueID: id.rawValue,
            icon: "mdi:dots-square",
            state: "unavailable"
        )
    }

    static func angleSensor(for state: HingeState) -> WebhookSensor {
        with(WebhookSensor(
            name: "Hinge Angle",
            uniqueID: WebhookSensorId.hingeAngle.rawValue,
            icon: "mdi:angle-acute",
            // The rate and precision of angle updates are system policy, so the value is rounded
            // rather than sent at whatever precision a given update happens to carry.
            state: (state.angleDegrees * 10).rounded() / 10,
            unit: "°",
            stateClass: .measurement
        )) {
            $0.Attributes = ["status": state.status.rawValue]
        }
    }

    static func statusSensor(for state: HingeState) -> WebhookSensor {
        with(WebhookSensor(
            name: "Hinge Status",
            uniqueID: WebhookSensorId.hingeStatus.rawValue,
            icon: state.status.icon,
            state: state.status.rawValue
        )) {
            $0.Attributes = ["angle": (state.angleDegrees * 10).rounded() / 10]
        }
    }
}

private extension HingeStatus {
    var icon: String {
        switch self {
        case .unknown:
            return "mdi:cellphone-remove"
        case .closed:
            return "mdi:cellphone"
        case .partiallyOpen:
            return "mdi:book-open-outline"
        case .fullyOpen:
            return "mdi:book-open-page-variant-outline"
        }
    }
}
