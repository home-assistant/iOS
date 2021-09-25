import Foundation
import HAKit
import PromiseKit

final class FocusSensorUpdateSignaler: SensorProviderUpdateSignaler {
    let cancellable: HACancellable
    init(signal: @escaping () -> Void) {
        self.cancellable = Current.focusStatus.trigger.observe { _ in
            // this means that we will double-update the focus sensor if the app is running
            // this feels less likely to happen, but allows us to keep the in-app visual state right
            if Current.isForegroundApp() {
                signal()
            }
        }
    }

    deinit {
        cancellable.cancel()
    }
}

final class FocusSensor: SensorProvider {
    public enum FocusError: Error, Equatable {
        case unauthorized
        case unavailable
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard Current.focusStatus.isAvailable() else {
            return .init(error: FocusError.unavailable)
        }

        guard Current.focusStatus.authorizationStatus() == .authorized else {
            return .init(error: FocusError.unauthorized)
        }

        let focusState = Current.focusStatus.status()
        var sensors = [WebhookSensor]()

        if let isFocused = focusState.isFocused {
            sensors.append(with(WebhookSensor(
                name: "Focus",
                uniqueID: "focus",
                icon: "mdi:moon-waning-crescent",
                state: isFocused
            )) {
                $0.Type = "binary_sensor"
            })
        }

        // Set up our observer
        let _: FocusSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value(sensors)
    }
}
