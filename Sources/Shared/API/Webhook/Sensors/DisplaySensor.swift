import Foundation
import PromiseKit

final class DisplaySensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    static var notificationName: Notification.Name {
        #if targetEnvironment(macCatalyst)
        return Current.macBridge.screensWillChangeNotification
        #else
        return .init(rawValue: "test_screensWillChangeNotification")
        #endif
    }

    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .displaysCount,
            .primaryDisplayName,
            .primaryDisplayId,
        ])
    }

    @objc private func screensDidChange(_ note: Notification) {
        signal()
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange(_:)),
            name: Self.notificationName,
            object: nil
        )
        isObserving = true
        #if DEBUG
        notifyObservation?()
        #endif
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: Self.notificationName,
            object: nil
        )
        isObserving = false
    }
}

final class DisplaySensor: SensorProvider {
    public enum DisplayError: Error, Equatable {
        case unsupportedPlatform
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard let screens = Current.device.screens() else {
            return .init(error: DisplayError.unsupportedPlatform)
        }

        var sensors = [WebhookSensor]()

        sensors.append(with(WebhookSensor(
            name: "Displays",
            uniqueID: WebhookSensorId.displaysCount.rawValue,
            icon: "mdi:monitor-multiple",
            state: screens.count
        )) {
            $0.Attributes = [
                "Display IDs": screens.map(\.identifier),
                "Display Names": screens.map(\.name),
            ]
        })

        sensors.append(WebhookSensor(
            name: "Primary Display Name",
            uniqueID: WebhookSensorId.primaryDisplayName.rawValue,
            icon: "mdi:monitor-star",
            state: screens.first.map(\.name) ?? "None"
        ))

        sensors.append(WebhookSensor(
            name: "Primary Display ID",
            uniqueID: WebhookSensorId.primaryDisplayId.rawValue,
            icon: "mdi:monitor-star",
            state: screens.first.map(\.identifier) ?? "None"
        ))

        // Set up our observer
        let _: DisplaySensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value(sensors)
    }
}
