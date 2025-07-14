import Foundation
import PromiseKit

final class FrontmostAppSensorUpdateSignaler: SensorProviderUpdateSignaler, SensorObserver {
    /// Indicates where observation is already happening
    private var isObserving = false
    /// Indicates where intial sensors update is going to happen
    private var firstUpdate = true

    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
        Current.sensors.register(observer: self)
    }

    @objc private func frontmostAppDidChange(_ note: Notification) {
        signal()
    }

    private func observe() {
        #if targetEnvironment(macCatalyst)
        guard !isObserving else { return }
        Current.macBridge.workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppDidChange(_:)),
            name: Current.macBridge.frontmostApplicationDidChangeNotification,
            object: nil
        )
        isObserving = true
        #endif
    }

    private func stopObserving() {
        #if targetEnvironment(macCatalyst)
        guard isObserving else { return }
        Current.macBridge.workspaceNotificationCenter.removeObserver(
            self,
            name: Current.macBridge.frontmostApplicationDidChangeNotification,
            object: nil
        )
        isObserving = false
        #endif
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        guard firstUpdate else { return }
        firstUpdate = false
        updateObservation(sensorUpdates: update)
    }

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason, lastUpdate: SensorObserverUpdate?) {
        guard reason == .settingsChange else { return }
        updateObservation(sensorUpdates: lastUpdate)
    }

    private func updateObservation(sensorUpdates: SensorObserverUpdate?) {
        sensorUpdates?.sensors.done { [weak self] sensors in
            guard let frontMostAppSensor = sensors.first(where: { sensor in
                sensor.UniqueID == WebhookSensorId.frontmostApp.rawValue
            }) else {
                return
            }
            if Current.sensors.isEnabled(sensor: frontMostAppSensor) {
                self?.observe()
            } else {
                self?.stopObserving()
            }
        }
    }
}

final class FrontmostAppSensor: SensorProvider {
    public enum FrostmostAppError: Error, Equatable {
        case unsupportedPlatform
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    private static let dateFormatter = with(ISO8601DateFormatter()) {
        $0.formatOptions = [.withInternetDateTime]
    }

    func sensors() -> Promise<[WebhookSensor]> {
        #if targetEnvironment(macCatalyst)
        var sensors = [WebhookSensor]()

        let frontmost = Current.macBridge.frontmostApplication

        sensors.append(with(WebhookSensor(
            name: "Frontmost App",
            uniqueID: WebhookSensorId.frontmostApp.rawValue,
            icon: "mdi:traffic-light",
            state: frontmost?.localizedName ?? "None"
        )) {
            var attributes = [String: Any]()

            attributes["Bundle Identifier"] = frontmost?.bundleIdentifier ?? "N/A"
            attributes["Launch Date"] = frontmost?.launchDate.map { Self.dateFormatter.string(from: $0) } ?? "N/A"
            attributes["Is Hidden"] = frontmost?.isHidden ?? "N/A"
            attributes["Owns Menu Bar"] = frontmost?.ownsMenuBar ?? "N/A"

            $0.Attributes = attributes
        })

        // Set up our observer
        let _: FrontmostAppSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value(sensors)
        #else
        return .init(error: FrostmostAppError.unsupportedPlatform)
        #endif
    }
}
