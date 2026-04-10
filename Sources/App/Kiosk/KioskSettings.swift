import Foundation
import GRDB
import Shared
import UIKit

// MARK: - GRDB Record Wrapper

public struct KioskSettingsRecord: Codable, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { GRDBDatabaseTable.kioskSettings.rawValue }
    public static let recordId = "kiosk-settings"

    public var id: String = KioskSettingsRecord.recordId
    public var settingsJSON: KioskSettings = .init()

    public static func settings() -> KioskSettings {
        do {
            let record: KioskSettingsRecord? = try Current.database().read { db in
                try KioskSettingsRecord.fetchOne(db, key: KioskSettingsRecord.recordId)
            }
            if let record {
                return record.settingsJSON
            } else {
                Current.Log.info("No saved kiosk settings found in GRDB, using defaults")
                return KioskSettings()
            }
        } catch {
            Current.Log.error("Failed to load kiosk settings from GRDB: \(error)")
            return KioskSettings()
        }
    }

    public static func save(_ settings: KioskSettings) {
        do {
            var record = KioskSettingsRecord()
            record.settingsJSON = settings
            try Current.database().write { db in
                try record.insert(db, onConflict: .replace)
            }
            Current.Log.verbose("Saved kiosk settings to GRDB")
        } catch {
            Current.Log.error("Failed to save kiosk settings to GRDB: \(error)")
        }
    }
}

// MARK: - Main Settings Container

/// Complete settings model for kiosk mode
/// All settings are Codable for persistence and HA integration sync
public struct KioskSettings: Codable, Equatable {
    // MARK: - Core Kiosk Mode

    /// Whether kiosk mode is currently enabled
    public var isKioskModeEnabled: Bool = false

    /// Whether device authentication (Face ID, Touch ID, or passcode) is required to access settings
    public var requireDeviceAuthentication: Bool = false

    /// Hide iOS status bar for full immersion
    public var hideStatusBar: Bool = true

    /// Prevent iOS from auto-locking the screen
    public var preventAutoLock: Bool = true

    // MARK: - Brightness Control

    /// Enable brightness management
    public var brightnessControlEnabled: Bool = true

    /// Manual brightness level (0.0 - 1.0)
    public var manualBrightness: Float = 0.8

    // MARK: - Screensaver

    /// Enable screensaver
    public var screensaverEnabled: Bool = true

    /// Screensaver mode
    public var screensaverMode: ScreensaverMode = .clock

    /// Seconds of idle before screensaver activates
    public var screensaverTimeout: TimeInterval = 300 // 5 minutes

    /// Brightness level when dimmed (0.0 - 1.0)
    public var screensaverDimLevel: Float = 0.1

    /// Enable pixel shifting for OLED burn-in prevention
    public var pixelShiftEnabled: Bool = true

    /// Pixel shift amount in points
    public var pixelShiftAmount: CGFloat = 10

    /// Pixel shift interval in seconds
    public var pixelShiftInterval: TimeInterval = 60

    // MARK: - Screensaver Clock Options

    /// Show seconds on clock
    public var clockShowSeconds: Bool = false

    /// Show date on clock
    public var clockShowDate: Bool = true

    /// Use 24-hour time format (false = 12-hour with AM/PM)
    public var clockUse24HourFormat: Bool = true

    /// Clock style
    public var clockStyle: ClockStyle = .large

    // MARK: - Secret Exit Gesture

    /// Enable secret gesture to access kiosk settings (escape hatch)
    public var secretExitGestureEnabled: Bool = true

    /// Corner for secret exit gesture
    public var secretExitGestureCorner: ScreenCorner = .bottomRight

    /// Number of taps required for secret exit gesture
    public var secretExitGestureTaps: Int = 3

    // MARK: - Camera Detection

    /// Enable camera-based motion detection
    public var cameraMotionEnabled: Bool = false

    /// Motion detection sensitivity
    public var cameraMotionSensitivity: MotionSensitivity = .medium

    /// Wake the screen when camera motion is detected
    public var wakeOnCameraMotion: Bool = false

    /// Enable camera-based presence (person) detection
    public var cameraPresenceEnabled: Bool = false

    /// Enable face detection (requires presence detection)
    public var cameraFaceDetectionEnabled: Bool = false

    /// Wake the screen when a person is detected by camera
    public var wakeOnCameraPresence: Bool = false

    // MARK: - Codable (backwards-compatible decoding)

    enum CodingKeys: String, CodingKey {
        case isKioskModeEnabled
        case requireDeviceAuthentication
        case hideStatusBar
        case preventAutoLock
        case brightnessControlEnabled
        case manualBrightness
        case screensaverEnabled
        case screensaverMode
        case screensaverTimeout
        case screensaverDimLevel
        case pixelShiftEnabled
        case pixelShiftAmount
        case pixelShiftInterval
        case clockShowSeconds
        case clockShowDate
        case clockUse24HourFormat
        case clockStyle
        case secretExitGestureEnabled
        case secretExitGestureCorner
        case secretExitGestureTaps
        case cameraMotionEnabled
        case cameraMotionSensitivity
        case wakeOnCameraMotion
        case cameraPresenceEnabled
        case cameraFaceDetectionEnabled
        case wakeOnCameraPresence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Core
        self.isKioskModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isKioskModeEnabled) ?? false
        self.requireDeviceAuthentication = try container.decodeIfPresent(
            Bool.self,
            forKey: .requireDeviceAuthentication
        ) ?? false
        self.hideStatusBar = try container.decodeIfPresent(Bool.self, forKey: .hideStatusBar) ?? true
        self.preventAutoLock = try container.decodeIfPresent(Bool.self, forKey: .preventAutoLock) ?? true

        // Brightness
        self.brightnessControlEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .brightnessControlEnabled
        ) ?? true
        self.manualBrightness = try container.decodeIfPresent(Float.self, forKey: .manualBrightness) ?? 0.8

        // Screensaver
        self.screensaverEnabled = try container.decodeIfPresent(Bool.self, forKey: .screensaverEnabled) ?? true
        self.screensaverMode = try container.decodeIfPresent(
            ScreensaverMode.self,
            forKey: .screensaverMode
        ) ?? .clock
        self.screensaverTimeout = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .screensaverTimeout
        ) ?? 300
        self.screensaverDimLevel = try container.decodeIfPresent(Float.self, forKey: .screensaverDimLevel) ?? 0.1
        self.pixelShiftEnabled = try container.decodeIfPresent(Bool.self, forKey: .pixelShiftEnabled) ?? true
        self.pixelShiftAmount = try container.decodeIfPresent(CGFloat.self, forKey: .pixelShiftAmount) ?? 10
        self.pixelShiftInterval = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .pixelShiftInterval
        ) ?? 60

        // Clock
        self.clockShowSeconds = try container.decodeIfPresent(Bool.self, forKey: .clockShowSeconds) ?? false
        self.clockShowDate = try container.decodeIfPresent(Bool.self, forKey: .clockShowDate) ?? true
        self.clockUse24HourFormat = try container.decodeIfPresent(
            Bool.self,
            forKey: .clockUse24HourFormat
        ) ?? true
        self.clockStyle = try container.decodeIfPresent(ClockStyle.self, forKey: .clockStyle) ?? .large

        // Secret Exit Gesture
        self.secretExitGestureEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .secretExitGestureEnabled
        ) ?? true
        self.secretExitGestureCorner = try container.decodeIfPresent(
            ScreenCorner.self,
            forKey: .secretExitGestureCorner
        ) ?? .bottomRight
        self.secretExitGestureTaps = try container.decodeIfPresent(
            Int.self,
            forKey: .secretExitGestureTaps
        ) ?? 3

        // Camera Detection
        self.cameraMotionEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .cameraMotionEnabled
        ) ?? false
        self.cameraMotionSensitivity = try container.decodeIfPresent(
            MotionSensitivity.self,
            forKey: .cameraMotionSensitivity
        ) ?? .medium
        self.wakeOnCameraMotion = try container.decodeIfPresent(
            Bool.self,
            forKey: .wakeOnCameraMotion
        ) ?? false
        self.cameraPresenceEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .cameraPresenceEnabled
        ) ?? false
        self.cameraFaceDetectionEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .cameraFaceDetectionEnabled
        ) ?? false
        self.wakeOnCameraPresence = try container.decodeIfPresent(
            Bool.self,
            forKey: .wakeOnCameraPresence
        ) ?? false
    }
}

// MARK: - Enums

public enum ScreensaverMode: String, Codable, CaseIterable {
    case blank
    case dim
    case clock

    public var displayName: String {
        switch self {
        case .blank: return L10n.Kiosk.Screensaver.Mode.blank
        case .dim: return L10n.Kiosk.Screensaver.Mode.dim
        case .clock: return L10n.Kiosk.Screensaver.Mode.clock
        }
    }
}

public enum ScreensaverTimeout: CaseIterable {
    case thirtySeconds
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes

    public var timeInterval: TimeInterval {
        switch self {
        case .thirtySeconds: return 30
        case .oneMinute: return 60
        case .twoMinutes: return 120
        case .fiveMinutes: return 300
        case .tenMinutes: return 600
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        }
    }

    public var displayName: String {
        switch self {
        case .thirtySeconds: return L10n.Kiosk.Screensaver.Timeout._30sec
        case .oneMinute: return L10n.Kiosk.Screensaver.Timeout._1min
        case .twoMinutes: return L10n.Kiosk.Screensaver.Timeout._2min
        case .fiveMinutes: return L10n.Kiosk.Screensaver.Timeout._5min
        case .tenMinutes: return L10n.Kiosk.Screensaver.Timeout._10min
        case .fifteenMinutes: return L10n.Kiosk.Screensaver.Timeout._15min
        case .thirtyMinutes: return L10n.Kiosk.Screensaver.Timeout._30min
        }
    }

    /// Initialize from a TimeInterval, defaulting to fiveMinutes if no match
    public init(from interval: TimeInterval) {
        self = Self.allCases.first { $0.timeInterval == interval } ?? .fiveMinutes
    }
}

public enum ClockStyle: String, Codable, CaseIterable {
    case large
    case minimal
    case analog
    case digital

    public var displayName: String {
        switch self {
        case .large: return L10n.Kiosk.Clock.Style.large
        case .minimal: return L10n.Kiosk.Clock.Style.minimal
        case .analog: return L10n.Kiosk.Clock.Style.analog
        case .digital: return L10n.Kiosk.Clock.Style.digital
        }
    }
}

public enum MotionSensitivity: String, Codable, CaseIterable {
    case low
    case medium
    case high

    public var threshold: Float {
        switch self {
        case .low: return 0.05
        case .medium: return 0.02
        case .high: return 0.008
        }
    }

    public var displayName: String {
        switch self {
        case .low: return L10n.Kiosk.Camera.Sensitivity.low
        case .medium: return L10n.Kiosk.Camera.Sensitivity.medium
        case .high: return L10n.Kiosk.Camera.Sensitivity.high
        }
    }
}

// MARK: - Screen State (for sensors)

public enum ScreenState: String, Codable {
    case on
    case dimmed
    case screensaver
    case off
}

public enum AppState: String, Codable {
    case active
    case background
}

public enum ScreenCorner: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var displayName: String {
        switch self {
        case .topLeft: return L10n.Kiosk.Corner.topLeft
        case .topRight: return L10n.Kiosk.Corner.topRight
        case .bottomLeft: return L10n.Kiosk.Corner.bottomLeft
        case .bottomRight: return L10n.Kiosk.Corner.bottomRight
        }
    }
}
