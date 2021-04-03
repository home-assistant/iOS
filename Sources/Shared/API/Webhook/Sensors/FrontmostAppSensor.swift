import Foundation
import PromiseKit

final class FrontmostAppSensorUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal

        #if targetEnvironment(macCatalyst)
        Current.macBridge.workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppDidChange(_:)),
            name: Current.macBridge.frontmostApplicationDidChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func frontmostAppDidChange(_ note: Notification) {
        signal()
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
            uniqueID: "frontmost_app",
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
