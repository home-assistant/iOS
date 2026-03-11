import Foundation
import GRDB
import Shared
import UIKit

// MARK: - GRDB Record Wrapper

/// GRDB record wrapper for persisting KioskSettings
/// Uses .jsonText column so GRDB handles Codable encoding/decoding automatically
public struct KioskSettingsRecord: Codable, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { GRDBDatabaseTable.kioskSettings.rawValue }
    public static let recordId = "kiosk-settings"

    public var id: String = KioskSettingsRecord.recordId
    public var settingsJSON: KioskSettings = .init()

    /// Load settings from database
    public static func loadSettings() -> KioskSettings {
        do {
            let record: KioskSettingsRecord? = try Current.database().read { db in
                try KioskSettingsRecord.fetchOne(db)
            }
            if let record {
                return record.settingsJSON
            }
            Current.Log.info("No saved kiosk settings found in GRDB, using defaults")
            return KioskSettings()
        } catch {
            Current.Log.error("Failed to load kiosk settings from GRDB: \(error)")
            return KioskSettings()
        }
    }

    /// Save settings to database
    public static func saveSettings(_ settings: KioskSettings) {
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

    // MARK: - Wake Triggers

    /// Wake screen on touch
    public var wakeOnTouch: Bool = true

    // MARK: - Secret Exit Gesture

    /// Enable secret gesture to access kiosk settings (escape hatch)
    public var secretExitGestureEnabled: Bool = true

    /// Corner for secret exit gesture
    public var secretExitGestureCorner: ScreenCorner = .topRight

    /// Number of taps required for secret exit gesture
    public var secretExitGestureTaps: Int = 3
}

// MARK: - Enums

public enum ScreensaverMode: String, Codable, CaseIterable {
    case blank = "blank"
    case dim = "dim"
    case clock = "clock"

    public var displayName: String {
        switch self {
        case .blank: return L10n.Kiosk.Screensaver.Mode.blank
        case .dim: return L10n.Kiosk.Screensaver.Mode.dim
        case .clock: return L10n.Kiosk.Screensaver.Mode.clock
        }
    }
}

public enum ClockStyle: String, Codable, CaseIterable {
    case large = "large"
    case minimal = "minimal"
    case analog = "analog"
    case digital = "digital"

    public var displayName: String {
        switch self {
        case .large: return L10n.Kiosk.Clock.Style.large
        case .minimal: return L10n.Kiosk.Clock.Style.minimal
        case .analog: return L10n.Kiosk.Clock.Style.analog
        case .digital: return L10n.Kiosk.Clock.Style.digital
        }
    }
}

// MARK: - Screen State (for sensors)

public enum ScreenState: String, Codable {
    case on = "on"
    case dimmed = "dimmed"
    case screensaver = "screensaver"
    case off = "off"
}

public enum AppState: String, Codable {
    case active = "active"
    case background = "background"
}

public enum ScreenCorner: String, Codable, CaseIterable {
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"

    public var displayName: String {
        switch self {
        case .topLeft: return L10n.Kiosk.Corner.topLeft
        case .topRight: return L10n.Kiosk.Corner.topRight
        case .bottomLeft: return L10n.Kiosk.Corner.bottomLeft
        case .bottomRight: return L10n.Kiosk.Corner.bottomRight
        }
    }
}
