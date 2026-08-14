import Foundation
import Shared

/// Runs the "Add to Home Assistant" flow for the Camera Stream sensor: pick a server (when there
/// is more than one), then create an MJPEG IP Camera config entry pointed at this device's stream,
/// with the URL and credentials already filled in.
@MainActor
final class AddCameraStreamToHomeAssistantViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case working
        case succeeded(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    var servers: [Server] {
        Current.servers.all
    }

    /// Whether tapping can accomplish anything: the stream server has to be running (the sensor
    /// enabled) and the device has to have an address Home Assistant can connect back to.
    var isAvailable: Bool {
        servers.isEmpty == false && Current.cameraStreamServer.streamURL != nil && Current.cameraStreamServer.isActive
    }

    /// The message explaining why the button is disabled, or `nil` when it isn't.
    var unavailableReason: String? {
        guard servers.isEmpty == false else { return nil }
        if Current.cameraStreamServer.isActive == false {
            return L10n.Sensors.CameraStream.AddToHomeAssistant.Error.inactive
        }
        if Current.cameraStreamServer.streamURL == nil {
            return L10n.Sensors.CameraStream.AddToHomeAssistant.Error.noAddress
        }
        return nil
    }

    /// The finished-flow message, or `nil` while there is nothing to report.
    var resultMessage: String? {
        switch state {
        case .idle, .working:
            return nil
        case let .succeeded(message), let .failed(message):
            return message
        }
    }

    var isWorking: Bool {
        state == .working
    }

    var didSucceed: Bool {
        if case .succeeded = state { return true }
        return false
    }

    func dismissResult() {
        state = .idle
    }

    /// The name the created camera gets, derived from the device name the app registers with.
    func cameraName(for server: Server) -> String {
        let deviceName = server.info.setting(for: .overrideDeviceName) ?? Current.device.deviceName()
        return L10n.Sensors.CameraStream.AddToHomeAssistant.cameraName(deviceName)
    }

    func add(to server: Server) {
        guard state != .working else { return }

        let streamServer = Current.cameraStreamServer
        guard let streamURL = streamServer.streamURL else {
            state = .failed(L10n.Sensors.CameraStream.AddToHomeAssistant.Error.noAddress)
            return
        }

        let userInput = MJPEGCameraConfigFlow.userInput(
            name: cameraName(for: server),
            streamURL: streamURL,
            username: streamServer.username,
            password: streamServer.password
        )

        state = .working

        Task { [weak self] in
            do {
                let outcome = try await HomeAssistantConfigFlowClient.createEntry(
                    server: server,
                    handler: MJPEGCameraConfigFlow.handler,
                    userInput: userInput
                )
                self?.state = Self.resultState(for: outcome, fallbackTitle: userInput["name"] as? String ?? "")
            } catch {
                Current.Log.error("Camera stream: adding MJPEG camera failed: \(error)")
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    /// Translates the flow's outcome into something worth showing. The failure codes come from the
    /// MJPEG integration's validation, which fetches the stream from the server's side of the
    /// network — so `cannot_connect` usually means the app is backgrounded or the server can't
    /// reach the device, not that the settings are wrong.
    static func resultState(for outcome: ConfigFlowOutcome, fallbackTitle: String) -> State {
        typealias Strings = L10n.Sensors.CameraStream.AddToHomeAssistant

        switch outcome {
        case let .created(title):
            return .succeeded(Strings.success(title.isEmpty ? fallbackTitle : title))
        case let .aborted(reason):
            if reason == "already_configured" {
                return .failed(Strings.Error.alreadyConfigured)
            }
            return .failed(Strings.Error.flow(reason))
        case let .form(_, errors):
            guard let code = errors.values.first else {
                return .failed(Strings.Error.flow("unknown"))
            }
            switch code {
            case "cannot_connect":
                return .failed(Strings.Error.cannotConnect)
            case "invalid_auth":
                return .failed(Strings.Error.invalidAuth)
            default:
                return .failed(Strings.Error.flow(code))
            }
        }
    }
}
