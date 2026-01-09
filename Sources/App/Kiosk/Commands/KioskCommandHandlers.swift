import Foundation
import PromiseKit
import Shared

// MARK: - Kiosk Notification Command Handlers

/// Handles `command_screen_on` - Wake the screen and exit screensaver
struct HandlerScreenOn: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.info("Received command_screen_on")

        DispatchQueue.main.async {
            KioskModeManager.shared.wakeScreen(source: "command")
        }

        return .value(())
    }
}

/// Handles `command_screen_off` - Start screensaver or blank screen
struct HandlerScreenOff: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.info("Received command_screen_off")

        let modeString = payload["mode"] as? String
        let mode = modeString.flatMap { ScreensaverMode(rawValue: $0) }

        DispatchQueue.main.async {
            KioskModeManager.shared.sleepScreen(mode: mode)
        }

        return .value(())
    }
}

/// Handles `command_brightness` - Set screen brightness level
struct HandlerBrightness: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let level = payload["level"] as? Int else {
            Current.Log.warning("command_brightness missing 'level' parameter")
            return .value(())
        }

        Current.Log.info("Received command_brightness: \(level)")

        DispatchQueue.main.async {
            KioskModeManager.shared.setBrightness(level)
        }

        return .value(())
    }
}

/// Handles `command_navigate` - Navigate to a URL or HA path
struct HandlerNavigate: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        // Support both 'path' and 'url' keys
        guard let path = (payload["path"] as? String) ?? (payload["url"] as? String) else {
            Current.Log.warning("command_navigate missing 'path' or 'url' parameter")
            return .value(())
        }

        Current.Log.info("Received command_navigate: \(path)")

        DispatchQueue.main.async {
            KioskModeManager.shared.navigate(to: path)
        }

        return .value(())
    }
}

/// Handles `command_refresh` - Reload the current page
struct HandlerRefresh: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.info("Received command_refresh")

        DispatchQueue.main.async {
            KioskModeManager.shared.refresh()
        }

        return .value(())
    }
}

/// Handles `command_screensaver` - Control screensaver state
struct HandlerScreensaver: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        let action = payload["action"] as? String ?? "toggle"
        let modeString = payload["mode"] as? String
        let mode = modeString.flatMap { ScreensaverMode(rawValue: $0) }

        Current.Log.info("Received command_screensaver: action=\(action), mode=\(mode?.rawValue ?? "default")")

        DispatchQueue.main.async {
            let manager = KioskModeManager.shared

            switch action {
            case "start", "on":
                manager.sleepScreen(mode: mode)
            case "stop", "off":
                manager.wakeScreen(source: "command")
            case "toggle":
                if manager.screenState == .on {
                    manager.sleepScreen(mode: mode)
                } else {
                    manager.wakeScreen(source: "command")
                }
            default:
                Current.Log.warning("Unknown screensaver action: \(action)")
            }
        }

        return .value(())
    }
}

/// Handles `command_kiosk_mode` - Enable/disable kiosk mode
struct HandlerKioskMode: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        // Parse enabled parameter outside MainActor context
        let explicitEnabled: Bool?
        if let enabledParam = payload["enabled"] as? Bool {
            explicitEnabled = enabledParam
        } else if let enabledString = payload["enabled"] as? String {
            explicitEnabled = enabledString.lowercased() == "true" || enabledString == "1"
        } else {
            explicitEnabled = nil // Will toggle
        }

        DispatchQueue.main.async {
            let enabled = explicitEnabled ?? !KioskModeManager.shared.isKioskModeActive
            Current.Log.info("Received command_kiosk_mode: enabled=\(enabled)")

            if enabled {
                KioskModeManager.shared.enableKioskMode()
            } else {
                KioskModeManager.shared.disableKioskMode()
            }
        }

        return .value(())
    }
}

/// Handles `command_volume` - Set device volume
struct HandlerVolume: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let level = payload["level"] as? Int else {
            Current.Log.warning("command_volume missing 'level' parameter")
            return .value(())
        }

        Current.Log.info("Received command_volume: \(level)")

        // Convert 0-100 level to 0.0-1.0 range for AudioManager
        let normalizedLevel = Float(max(0, min(100, level))) / 100.0

        DispatchQueue.main.async {
            AudioManager.shared.setVolume(normalizedLevel)
        }

        return .value(())
    }
}

/// Handles `command_tts` - Text-to-speech announcement
struct HandlerTTS: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let message = payload["message"] as? String else {
            Current.Log.warning("command_tts missing 'message' parameter")
            return .value(())
        }

        let volume = payload["volume"] as? Float

        Current.Log.info("Received command_tts: \(message)")

        DispatchQueue.main.async {
            if let vol = volume {
                AudioManager.shared.setVolume(vol)
            }
            AudioManager.shared.speak(message, priority: .high)
        }

        return .value(())
    }
}

/// Handles `command_launch_app` - Launch an external app
struct HandlerLaunchApp: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let scheme = payload["scheme"] as? String else {
            Current.Log.warning("command_launch_app missing 'scheme' parameter")
            return .value(())
        }

        let name = payload["name"] as? String

        Current.Log.info("Received command_launch_app: \(scheme)")

        DispatchQueue.main.async {
            KioskModeManager.shared.launchApp(scheme: scheme, name: name)
        }

        return .value(())
    }
}

/// Handles `command_return` - Bring HAFrame back to foreground
struct HandlerReturn: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.info("Received command_return")

        // Send a local notification that will bring the user back
        let content = UNMutableNotificationContent()
        content.title = "HAFrame"
        content.body = "Tap to return to your dashboard"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "haframe_return",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)

        return .value(())
    }
}

/// Handles `command_show_camera` - Show camera overlay/popup
struct HandlerShowCamera: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let entityId = payload["entity_id"] as? String else {
            Current.Log.warning("command_show_camera missing 'entity_id' parameter")
            return .value(())
        }

        let name = payload["name"] as? String ?? entityId.replacingOccurrences(of: "camera.", with: "").replacingOccurrences(of: "_", with: " ").capitalized
        let typeString = payload["type"] as? String ?? "generic"
        let streamTypeString = payload["stream_type"] as? String ?? "mjpeg"
        let unlockEntityId = payload["unlock_entity_id"] as? String
        let autoDismiss: TimeInterval? = (payload["auto_dismiss"] as? TimeInterval) ?? (payload["auto_dismiss"] as? Int).map { TimeInterval($0) }
        let showActions = payload["show_actions"] as? Bool ?? (typeString == "doorbell")

        // Alert sound parameters
        let soundString = payload["sound"] as? String
        let alertSound: CameraStream.AlertSound? = soundString.flatMap { CameraStream.AlertSound(rawValue: $0) }
        let alertVolume: Float? = (payload["sound_volume"] as? Double).map { Float($0) } ??
                                  (payload["sound_volume"] as? Float)

        // Parse custom actions
        let customActions: [CameraStream.CameraAction]? = parseCustomActions(from: payload)

        // Determine camera type
        let cameraType: CameraStream.CameraType
        switch typeString.lowercased() {
        case "doorbell": cameraType = .doorbell
        case "security": cameraType = .security
        default: cameraType = .generic
        }

        // Determine stream type preference
        let preferHLS = streamTypeString.lowercased() == "hls"

        Current.Log.info("Received command_show_camera: \(entityId)")

        // Wake the screen first so the camera popup is visible
        DispatchQueue.main.async {
            KioskModeManager.shared.wakeScreen(source: "camera_popup")
        }

        // Get proper stream paths from Home Assistant via StreamCamera API
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.error("No HA connection for camera stream")
            return .value(())
        }

        return firstly {
            api.StreamCamera(entityId: entityId)
        }.recover { error -> Promise<StreamCameraResponse> in
            // Fall back to hardcoded path if StreamCamera fails (older HA versions)
            Current.Log.info("StreamCamera failed, falling back to default path: \(error.localizedDescription)")
            return .value(StreamCameraResponse(fallbackEntityID: entityId))
        }.done { response in
            // Determine actual stream type based on what's available
            let streamType: CameraStream.StreamType
            let hlsURL: URL?
            let mjpegPath: String?

            if preferHLS, let hlsPath = response.hlsPath,
               let url = api.server.info.connection.activeURL()?.appendingPathComponent(hlsPath) {
                streamType = .hls
                hlsURL = url
                mjpegPath = response.mjpegPath
            } else if let path = response.mjpegPath {
                streamType = .mjpeg
                hlsURL = nil
                mjpegPath = path
            } else {
                Current.Log.error("No stream path available for camera: \(entityId)")
                return
            }

            let stream = CameraStream(
                name: name,
                entityId: entityId,
                type: cameraType,
                streamType: streamType,
                hlsURL: hlsURL,
                mjpegPath: mjpegPath,
                showActions: showActions,
                unlockEntityId: unlockEntityId,
                autoDismissSeconds: autoDismiss,
                alertSound: alertSound,
                alertVolume: alertVolume,
                customActions: customActions
            )

            DispatchQueue.main.async {
                CameraOverlayManager.shared.show(stream: stream)
            }
        }
    }

    /// Parse custom actions from payload
    private func parseCustomActions(from payload: [String: Any]) -> [CameraStream.CameraAction]? {
        guard let actionsArray = payload["actions"] as? [[String: Any]], !actionsArray.isEmpty else {
            return nil
        }

        return actionsArray.compactMap { actionDict -> CameraStream.CameraAction? in
            guard let label = actionDict["label"] as? String,
                  let service = actionDict["service"] as? String else {
                return nil
            }

            return CameraStream.CameraAction(
                id: actionDict["id"] as? String ?? UUID().uuidString,
                label: label,
                icon: actionDict["icon"] as? String,
                service: service,
                target: actionDict["target"] as? [String: Any],
                serviceData: actionDict["data"] as? [String: Any],
                confirmRequired: actionDict["confirm"] as? Bool ?? false
            )
        }
    }
}

/// Handles `command_dismiss_camera` - Dismiss camera overlay
struct HandlerDismissCamera: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Current.Log.info("Received command_dismiss_camera")

        DispatchQueue.main.async {
            CameraOverlayManager.shared.dismiss()
        }

        return .value(())
    }
}

/// Handles `command_play_audio` - Play an audio file
struct HandlerPlayAudio: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let url = payload["url"] as? String else {
            Current.Log.warning("command_play_audio missing 'url' parameter")
            return .value(())
        }

        let volume = payload["volume"] as? Float

        Current.Log.info("Received command_play_audio: \(url)")

        DispatchQueue.main.async {
            AudioManager.shared.playAudio(from: url, volume: volume)
        }

        return .value(())
    }
}

// MARK: - Registration Extension

extension NotificationCommandManager {
    /// Register all HAFrame kiosk command handlers
    /// Call this during app initialization
    public func registerKioskCommands() {
        // Screen control
        register(command: "command_screen_on", handler: HandlerScreenOn())
        register(command: "command_screen_off", handler: HandlerScreenOff())
        register(command: "command_brightness", handler: HandlerBrightness())
        register(command: "command_screensaver", handler: HandlerScreensaver())

        // Navigation
        register(command: "command_navigate", handler: HandlerNavigate())
        register(command: "command_refresh", handler: HandlerRefresh())

        // Kiosk mode
        register(command: "command_kiosk_mode", handler: HandlerKioskMode())

        // Audio
        register(command: "command_volume", handler: HandlerVolume())
        register(command: "command_tts", handler: HandlerTTS())
        register(command: "command_play_audio", handler: HandlerPlayAudio())

        // App launcher
        register(command: "command_launch_app", handler: HandlerLaunchApp())
        register(command: "command_return", handler: HandlerReturn())

        // Camera
        register(command: "command_show_camera", handler: HandlerShowCamera())
        register(command: "command_dismiss_camera", handler: HandlerDismissCamera())

        Current.Log.info("Registered \(14) kiosk notification commands")
    }
}
