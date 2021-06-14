import Foundation
import PromiseKit

final class FocusSensor: SensorProvider {
    public enum FocusError: Error, Equatable {
        case unauthorized
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard Current.focusStatus.authorizationStatus() == .authorized else {
            return .init(error: FocusError.unauthorized)
        }

        let focusState = Current.focusStatus.status()
        var sensors = [WebhookSensor]()

        if let isFocused = focusState.isFocused {
            sensors.append(with(WebhookSensor(
                name: "Is Focused",
                uniqueID: "is_focused",
                icon: "mdi:moon-waning-crescent",
                state: isFocused
            )) {
                $0.Type = "binary_sensor"
            })
        }

        return .value(sensors)
    }
}
