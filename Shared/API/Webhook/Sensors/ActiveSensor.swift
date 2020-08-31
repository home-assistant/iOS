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
        guard Current.activeState.canTrackActiveStatus else {
            return .init(error: ActiveError.noActiveState)
        }

        let activeState = Current.activeState

        let sensor = WebhookSensor(
            name: "active",
            uniqueID: "active",
            icon: .radioactiveIcon,
            state: activeState.isActive
        )
        sensor.Attributes = [
            "Screensaver": activeState.isScreensavering,
            "Locked": activeState.isLocked,
            "Screen Off": activeState.isScreenOff,
            "Fast User Switched": activeState.isFastUserSwitched,
            "Sleeping": activeState.isSleeping
        ]

        // Set up our observer
        let _: ActiveSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
    }
}
