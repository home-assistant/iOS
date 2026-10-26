import Foundation
import HAKit
import PromiseKit

final class FocusSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    var cancellable: HACancellable?
    private var focusFilterCancellable: HACancellable?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .focus,
        ])
    }

    deinit {
        cancellable?.cancel()
        focusFilterCancellable?.cancel()
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        cancellable = Current.focusStatus.pushes.observe { [weak self] _ in
            #if os(watchOS)
            self?.signal()
            #else
            // The Intents extension that received the push reports it itself, so this only keeps
            // the sensor on screen current. In the background it would be a whole extra update.
            if Current.isForegroundApp() {
                self?.signal()
            }
            #endif
        }
        // A Focus Filter run turns the sensor on for a Focus whose status iOS doesn't report, and
        // the run's own update can fail to reach the server.
        focusFilterCancellable = Current.focusFilter.runs.observe { [weak self] _ in
            self?.signal()
        }
        isObserving = true

        #if DEBUG
        notifyObservation?()
        #endif
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        cancellable?.cancel()
        focusFilterCancellable?.cancel()
        isObserving = false
    }
}

/// Whether any Focus is on, see `FocusReport`.
final class FocusSensor: SensorProvider {
    public enum FocusError: Error, Equatable {
        case unavailable
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        // Only a device without Focus has no sensor to offer. Anything else stays listed, since
        // the list row is the only switch there is.
        guard Current.focusStatus.isAvailable() else {
            return .init(error: FocusError.unavailable)
        }

        return FocusReport.current().map { [self] report in
            let _: FocusSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

            guard let isFocused = report.isFocused else {
                // Nothing says, which is where a missing permission leaves it: switching the
                // sensor on is what asks for it.
                return [WebhookSensor(
                    awaitingPermissionNamed: "Focus",
                    uniqueID: WebhookSensorId.focus.rawValue,
                    type: "binary_sensor"
                )]
            }

            return [with(WebhookSensor(
                name: "Focus",
                uniqueID: WebhookSensorId.focus.rawValue,
                icon: "mdi:moon-waning-crescent",
                state: isFocused
            )) {
                $0.Type = "binary_sensor"
            }]
        }
    }
}
