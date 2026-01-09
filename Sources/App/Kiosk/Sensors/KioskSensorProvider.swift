import Foundation
import PromiseKit
import Shared
import UIKit

// MARK: - Kiosk Sensor IDs

enum KioskSensorId {
    static let kioskMode = "kiosk_mode"
    static let kioskScreenState = "kiosk_screen_state"
    static let kioskBrightness = "kiosk_brightness"
    static let kioskCurrentDashboard = "kiosk_current_dashboard"
    static let kioskScreensaverState = "kiosk_screensaver_state"
    static let kioskLastActivity = "kiosk_last_activity"
    static let kioskLastWakeSource = "kiosk_last_wake_source"
    static let kioskAppState = "kiosk_app_state"
    static let kioskMotionDetected = "kiosk_motion_detected"
    static let kioskPresenceDetected = "kiosk_presence_detected"
    static let kioskOrientation = "kiosk_orientation"
    static let kioskTamper = "kiosk_tamper"
    static let kioskAmbientAudio = "kiosk_ambient_audio"
}

// MARK: - Update Signaler

final class KioskSensorUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal

        // Listen for kiosk state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKioskUpdate),
            name: .kioskSensorUpdate,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKioskUpdate),
            name: KioskModeManager.screenStateDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKioskUpdate),
            name: KioskModeManager.kioskModeDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKioskUpdate),
            name: KioskModeManager.settingsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleKioskUpdate() {
        signal()
    }
}

// MARK: - Kiosk Sensor Provider

public final class KioskSensorProvider: SensorProvider {
    public let request: SensorProviderRequest
    private var updateSignaler: KioskSensorUpdateSignaler?

    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    @MainActor
    public func sensors() -> Promise<[WebhookSensor]> {
        // Set up update signaler and retain it
        updateSignaler = request.dependencies.updateSignaler(for: self)

        let manager = KioskModeManager.shared
        let settings = manager.settings
        var sensors = [WebhookSensor]()

        // Kiosk Mode (binary sensor)
        sensors.append(with(WebhookSensor(name: "Kiosk Kiosk Mode", uniqueID: KioskSensorId.kioskMode)) {
            $0.Icon = manager.isKioskModeActive ? "mdi:fullscreen" : "mdi:fullscreen-exit"
            $0.State = manager.isKioskModeActive ? "on" : "off"
            $0.entityCategory = "diagnostic"
        })

        // Screen State
        sensors.append(with(WebhookSensor(name: "Kiosk Screen State", uniqueID: KioskSensorId.kioskScreenState)) {
            $0.Icon = iconForScreenState(manager.screenState)
            $0.State = manager.screenState.rawValue
            $0.entityCategory = "diagnostic"
            $0.Attributes = [
                "screensaver_mode": manager.activeScreensaverMode?.rawValue ?? "none"
            ]
        })

        // Brightness
        sensors.append(with(WebhookSensor(name: "Kiosk Brightness", uniqueID: KioskSensorId.kioskBrightness)) {
            $0.Icon = iconForBrightness(manager.currentBrightness)
            $0.State = Int(manager.currentBrightness * 100)
            $0.UnitOfMeasurement = "%"
            $0.entityCategory = "diagnostic"
            $0.Attributes = ["state_class": "measurement"]
        })

        // Current Dashboard
        sensors.append(with(WebhookSensor(name: "Kiosk Current Dashboard", uniqueID: KioskSensorId.kioskCurrentDashboard)) {
            $0.Icon = "mdi:view-dashboard"
            $0.State = manager.currentDashboard.isEmpty ? "none" : manager.currentDashboard
            $0.entityCategory = "diagnostic"
        })

        // Screensaver State
        sensors.append(with(WebhookSensor(name: "Kiosk Screensaver", uniqueID: KioskSensorId.kioskScreensaverState)) {
            $0.Icon = "mdi:monitor-shimmer"
            $0.State = manager.activeScreensaverMode?.rawValue ?? "inactive"
            $0.entityCategory = "diagnostic"
        })

        // Last Activity
        let dateFormatter = ISO8601DateFormatter()
        sensors.append(with(WebhookSensor(name: "Kiosk Last Activity", uniqueID: KioskSensorId.kioskLastActivity)) {
            $0.Icon = "mdi:gesture-tap"
            $0.DeviceClass = .timestamp
            $0.State = dateFormatter.string(from: manager.lastActivityTime)
            $0.entityCategory = "diagnostic"
        })

        // Last Wake Source
        sensors.append(with(WebhookSensor(name: "Kiosk Last Wake Source", uniqueID: KioskSensorId.kioskLastWakeSource)) {
            $0.Icon = "mdi:power-standby"
            $0.State = manager.lastWakeSource
            $0.entityCategory = "diagnostic"
        })

        // App State (with away tracking from AppLauncherManager)
        let launcher = AppLauncherManager.shared
        sensors.append(with(WebhookSensor(name: "Kiosk App State", uniqueID: KioskSensorId.kioskAppState)) {
            $0.Icon = iconForAppState(launcher.appState)
            $0.State = launcher.sensorState
            $0.Attributes = launcher.sensorAttributes
            $0.entityCategory = "diagnostic"
        })

        // Orientation
        sensors.append(with(WebhookSensor(name: "Kiosk Orientation", uniqueID: KioskSensorId.kioskOrientation)) {
            $0.Icon = iconForOrientation(manager.currentOrientation)
            $0.State = manager.currentOrientation.rawValue
            $0.entityCategory = "diagnostic"
        })

        // Tamper Detection (binary sensor)
        if settings.tamperDetectionEnabled {
            sensors.append(with(WebhookSensor(name: "Kiosk Tamper", uniqueID: KioskSensorId.kioskTamper)) {
                $0.Icon = manager.tamperDetected ? "mdi:shield-alert" : "mdi:shield-check"
                $0.DeviceClass = .tamper
                $0.State = manager.tamperDetected ? "on" : "off"
                $0.entityCategory = "diagnostic"
            })
        }

        // Motion Detected (binary sensor) - only if enabled
        if settings.cameraMotionEnabled && settings.reportMotionToHA {
            let cameraManager = CameraDetectionManager.shared
            sensors.append(with(WebhookSensor(name: "Kiosk Motion", uniqueID: KioskSensorId.kioskMotionDetected)) {
                $0.Icon = cameraManager.motionDetected ? "mdi:motion-sensor" : "mdi:motion-sensor-off"
                $0.DeviceClass = .motion
                $0.State = cameraManager.motionSensorState
                $0.Attributes = cameraManager.motionSensorAttributes
                $0.entityCategory = "diagnostic"
            })
        }

        // Presence Detected (binary sensor) - only if enabled
        if settings.cameraPresenceEnabled && settings.reportPresenceToHA {
            let cameraManager = CameraDetectionManager.shared
            sensors.append(with(WebhookSensor(name: "Kiosk Presence", uniqueID: KioskSensorId.kioskPresenceDetected)) {
                $0.Icon = cameraManager.presenceDetected ? "mdi:account-check" : "mdi:account-off"
                $0.DeviceClass = .occupancy
                $0.State = cameraManager.presenceSensorState
                $0.Attributes = cameraManager.presenceSensorAttributes
                $0.entityCategory = "diagnostic"
            })
        }

        // Ambient Audio Level - only if enabled
        if settings.ambientAudioDetectionEnabled {
            let audioDetector = AmbientAudioDetector.shared
            var audioAttrs = audioDetector.sensorAttributes
            audioAttrs["state_class"] = "measurement"
            sensors.append(with(WebhookSensor(name: "Kiosk Ambient Audio", uniqueID: KioskSensorId.kioskAmbientAudio)) {
                $0.Icon = audioDetector.loudAudioDetected ? "mdi:volume-high" : "mdi:volume-medium"
                $0.State = audioDetector.audioLevelPercent
                $0.UnitOfMeasurement = "%"
                $0.Attributes = audioAttrs
                $0.entityCategory = "diagnostic"
            })
        }

        return .value(sensors)
    }

    // MARK: - Icon Helpers

    private func iconForScreenState(_ state: ScreenState) -> String {
        switch state {
        case .on:
            return "mdi:monitor"
        case .dimmed:
            return "mdi:monitor-shimmer"
        case .screensaver:
            return "mdi:monitor-star"
        case .off:
            return "mdi:monitor-off"
        }
    }

    private func iconForBrightness(_ brightness: Float) -> String {
        switch brightness {
        case 0..<0.25:
            return "mdi:brightness-4"
        case 0.25..<0.5:
            return "mdi:brightness-5"
        case 0.5..<0.75:
            return "mdi:brightness-6"
        default:
            return "mdi:brightness-7"
        }
    }

    private func iconForAppState(_ state: AppState) -> String {
        switch state {
        case .active:
            return "mdi:application"
        case .away:
            return "mdi:application-export"
        case .background:
            return "mdi:application-outline"
        }
    }

    private func iconForOrientation(_ orientation: OrientationLock) -> String {
        switch orientation {
        case .portrait, .current:
            return "mdi:phone-rotate-portrait"
        case .portraitUpsideDown:
            return "mdi:phone-rotate-portrait"
        case .landscape, .landscapeLeft, .landscapeRight:
            return "mdi:phone-rotate-landscape"
        }
    }
}
