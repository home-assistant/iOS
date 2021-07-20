import Foundation
import PromiseKit

final class ActiveSensorUpdateSignaler: SensorProviderUpdateSignaler, ActiveStateObserver {
    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal

        Current.activeState.register(observer: self)
    }

    func activeStateDidChange(for manager: ActiveStateManager) {
        signal()
    }
}

final class ActiveSensor: SensorProvider {
    public enum ActiveError: Error, Equatable {
        case noActiveState
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        let activeState = Current.activeState

        guard activeState.canTrackActiveStatus else {
            return .init(error: ActiveError.noActiveState)
        }

        let isActive = activeState.isActive

        let sensor = WebhookSensor(
            name: "Active",
            uniqueID: "active",
            icon: isActive ? "mdi:monitor" : "mdi:monitor-off",
            state: isActive
        )
        sensor.Type = "binary_sensor"
        sensor.Attributes = activeState.states.attributes

        let durationFormatter = with(DateComponentsFormatter()) {
            $0.allowedUnits = [.minute, .second]
            $0.allowsFractionalUnits = true
            $0.formattingContext = .standalone
            $0.unitsStyle = .short
        }

        sensor.Settings = [
            .init(
                type: .stepper(
                    getter: { activeState.minimumIdleTime.converted(to: .minutes).value },
                    setter: { activeState.minimumIdleTime = .init(value: $0, unit: .minutes) },
                    minimum: 0.25,
                    maximum: .greatestFiniteMagnitude,
                    step: 0.25,
                    displayValueFor: { value in
                        let valueMeasurement = Measurement<UnitDuration>(value: value ?? 0, unit: .minutes)
                        return durationFormatter.string(from: valueMeasurement.converted(to: .seconds).value)
                    }
                ),
                title: L10n.Sensors.Active.Setting.timeUntilIdle
            ),
        ]

        // Set up our observer
        let _: ActiveSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
    }
}
