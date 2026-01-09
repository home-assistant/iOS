import Foundation
import UIKit

// MARK: - Main Settings Container

/// Complete settings model for kiosk mode
/// All settings are Codable for persistence and HA integration sync
public struct KioskSettings: Codable, Equatable {

    // MARK: - Core Kiosk Mode

    /// Whether kiosk mode is currently enabled
    var isEnabled: Bool = false

    /// PIN required to exit kiosk mode (empty = no PIN)
    var exitPIN: String = ""

    /// Whether biometric (Face ID/Touch ID) can be used to exit
    var allowBiometricExit: Bool = true

    /// Whether device passcode can be used to exit (instead of custom PIN)
    var allowDevicePasscodeExit: Bool = false

    /// Lock navigation (disable back gestures, pull-to-refresh, etc.)
    var navigationLockdown: Bool = true

    /// Hide iOS status bar for full immersion
    var hideStatusBar: Bool = true

    /// Prevent accidental edge touches
    var edgeProtection: Bool = false

    /// Edge protection inset in points
    var edgeProtectionInset: CGFloat = 20

    // MARK: - Dashboard Configuration

    /// Primary dashboard URL/path
    var primaryDashboardURL: String = ""

    /// Append ?kiosk to dashboard URLs (for kiosk-mode HACS integration)
    var appendKioskParameter: Bool = false

    /// All configured dashboards
    var dashboards: [DashboardConfig] = []

    /// Dashboard schedule entries
    var dashboardSchedule: [DashboardScheduleEntry] = []

    /// Enable dashboard rotation
    var rotationEnabled: Bool = false

    /// Rotation interval in seconds
    var rotationInterval: TimeInterval = 60

    /// Pause rotation when user touches screen
    var pauseRotationOnTouch: Bool = true

    /// Resume rotation after this many seconds of idle
    var resumeRotationAfterIdle: TimeInterval = 30

    // MARK: - Auto Refresh

    /// Legacy: Enable automatic refresh (kept for backwards compatibility)
    /// Now controlled by autoRefreshInterval > 0
    var autoRefreshEnabled: Bool = true

    /// Periodic refresh interval in seconds (0 = never)
    var autoRefreshInterval: TimeInterval = 0

    /// Refresh when waking from screensaver/dim
    var refreshOnWake: Bool = true

    /// Refresh when network reconnects
    var refreshOnNetworkReconnect: Bool = true

    /// Refresh when HA WebSocket reconnects
    var refreshOnHAReconnect: Bool = true

    // MARK: - Brightness Control

    /// Enable brightness management
    var brightnessControlEnabled: Bool = true

    /// Manual brightness level (0.0 - 1.0)
    var manualBrightness: Float = 0.8

    /// Enable day/night brightness schedule
    var brightnessScheduleEnabled: Bool = false

    /// Daytime brightness level (0.0 - 1.0)
    var dayBrightness: Float = 0.8

    /// Nighttime brightness level (0.0 - 1.0)
    var nightBrightness: Float = 0.3

    /// Time when day brightness starts (hour, minute)
    var dayStartTime: TimeOfDay = TimeOfDay(hour: 7, minute: 0)

    /// Time when night brightness starts (hour, minute)
    var nightStartTime: TimeOfDay = TimeOfDay(hour: 22, minute: 0)

    // MARK: - Screensaver

    /// Enable screensaver
    var screensaverEnabled: Bool = true

    /// Screensaver mode
    var screensaverMode: ScreensaverMode = .clock

    /// Seconds of idle before screensaver activates
    var screensaverTimeout: TimeInterval = 300 // 5 minutes

    /// Brightness level when dimmed (0.0 - 1.0) - used when schedule is disabled
    var screensaverDimLevel: Float = 0.1

    /// Enable day/night screensaver brightness schedule (uses same times as main brightness)
    var screensaverBrightnessScheduleEnabled: Bool = false

    /// Daytime screensaver brightness level (0.0 - 1.0)
    var screensaverDayDimLevel: Float = 0.15

    /// Nighttime screensaver brightness level (0.0 - 1.0)
    var screensaverNightDimLevel: Float = 0.05

    /// Enable pixel shifting for OLED burn-in prevention
    var pixelShiftEnabled: Bool = true

    /// Pixel shift amount in points
    var pixelShiftAmount: CGFloat = 10

    /// Pixel shift interval in seconds
    var pixelShiftInterval: TimeInterval = 60

    // MARK: - Screensaver Clock Options

    /// Show seconds on clock
    var clockShowSeconds: Bool = false

    /// Show date on clock
    var clockShowDate: Bool = true

    /// Use 24-hour time format (false = 12-hour with AM/PM)
    var clockUse24HourFormat: Bool = true

    /// Clock style
    var clockStyle: ClockStyle = .large

    /// HA entities to display on clock screensaver
    var clockEntities: [ClockEntityConfig] = []

    // MARK: - Screensaver Photos

    /// Photo source for screensaver
    var photoSource: PhotoSource = .local

    /// Selected local photo album identifiers
    var localPhotoAlbums: [String] = []

    /// iCloud shared album identifiers
    var iCloudAlbums: [String] = []

    /// HA Media Browser path for photos
    var haMediaPath: String = ""

    /// Photo display interval in seconds
    var photoInterval: TimeInterval = 30

    /// Photo transition style
    var photoTransition: PhotoTransition = .fade

    /// Photo fit mode (fill or fit)
    var photoFitMode: PhotoFitMode = .fill

    /// Show clock overlay on photos
    var photoShowClockOverlay: Bool = true

    /// Show entity data overlay on photos
    var photoShowEntityOverlay: Bool = false

    // MARK: - Screensaver Custom URL

    /// Custom URL to load as screensaver (e.g., a minimal HA dashboard)
    var screensaverCustomURL: String = ""

    // MARK: - Wake/Sleep Triggers

    /// Wake screen on touch
    var wakeOnTouch: Bool = true

    /// Wake screen on camera motion detection
    var wakeOnCameraMotion: Bool = false

    /// Wake screen on camera presence/face detection
    var wakeOnCameraPresence: Bool = false

    /// External HA entities that trigger wake
    var wakeEntities: [EntityTrigger] = []

    /// External HA entities that trigger sleep
    var sleepEntities: [EntityTrigger] = []

    /// Wake schedule entries
    var wakeSchedule: [ScheduleEntry] = []

    /// Sleep schedule entries
    var sleepSchedule: [ScheduleEntry] = []

    // MARK: - Entity Action Triggers

    /// Entity state changes that trigger actions
    var entityTriggers: [EntityActionTrigger] = []

    // MARK: - Camera & Presence Detection

    /// Enable camera-based motion detection
    var cameraMotionEnabled: Bool = false

    /// Motion detection sensitivity
    var cameraMotionSensitivity: MotionSensitivity = .medium

    /// Enable person presence detection (Vision framework)
    var cameraPresenceEnabled: Bool = false

    /// Enable face detection (more accurate than presence)
    var cameraFaceDetectionEnabled: Bool = false

    /// Report motion to HA as sensor
    var reportMotionToHA: Bool = true

    /// Report presence to HA as sensor
    var reportPresenceToHA: Bool = true

    // MARK: - Camera Popup

    /// Camera popup size when showing doorbell/security cameras
    var cameraPopupSize: CameraPopupSize = .large

    /// Camera popup position on screen
    var cameraPopupPosition: CameraPopupPosition = .center

    // MARK: - Audio

    /// Enable TTS announcements
    var ttsEnabled: Bool = true

    /// TTS volume (0.0 - 1.0)
    var ttsVolume: Float = 0.7

    /// Enable audio alerts for critical events
    var audioAlertsEnabled: Bool = true

    /// Enable ambient audio level detection
    var ambientAudioDetectionEnabled: Bool = false

    // MARK: - App Launcher

    /// Configured app shortcuts
    var appShortcuts: [AppShortcut] = []

    /// Show quick launch panel
    var quickLaunchEnabled: Bool = false

    /// Quick launch gesture
    var quickLaunchGesture: QuickLaunchGesture = .swipeFromBottom

    /// Return reminder timeout in seconds (0 = disabled)
    var appLaunchReturnTimeout: TimeInterval = 300 // 5 minutes

    // MARK: - Status Overlay

    /// Show status overlay bar
    var statusOverlayEnabled: Bool = true

    /// Status overlay position
    var statusOverlayPosition: OverlayPosition = .top

    /// Show connection status indicator
    var showConnectionStatus: Bool = true

    /// Show current time
    var showTime: Bool = false

    /// Show battery indicator
    var showBattery: Bool = true

    /// HA entities to show in status overlay
    var statusOverlayEntities: [String] = []

    /// Auto-hide overlay after seconds (0 = always visible)
    var statusOverlayAutoHide: TimeInterval = 5

    // MARK: - Quick Actions

    /// Enable quick actions bar
    var quickActionsEnabled: Bool = false

    /// Quick action gesture to reveal
    var quickActionsGesture: QuickLaunchGesture = .swipeFromRight

    /// Configured quick actions
    var quickActions: [QuickAction] = []

    // MARK: - Device & Security

    /// Orientation lock setting
    var orientationLock: OrientationLock = .current

    /// Enable tamper detection (orientation change alerts)
    var tamperDetectionEnabled: Bool = false

    /// Enable touch feedback sounds
    var touchSoundEnabled: Bool = false

    /// Enable touch haptic feedback
    var touchHapticEnabled: Bool = true

    /// Auto-restart app on crash
    var autoRestartOnCrash: Bool = true

    /// Low battery alert threshold (0-100, 0 = disabled)
    var lowBatteryAlertThreshold: Int = 20

    /// Report thermal state to HA
    var reportThermalState: Bool = true

    // MARK: - Secret Exit Gesture

    /// Enable secret gesture to access kiosk settings (escape hatch)
    var secretExitGestureEnabled: Bool = true

    /// Corner for secret exit gesture
    var secretExitGestureCorner: ScreenCorner = .topLeft

    /// Number of taps required for secret exit gesture
    var secretExitGestureTaps: Int = 3

    // MARK: - Enhanced Security (Sprint 9)

    /// Enable Guided Access integration
    var guidedAccessEnabled: Bool = false

    /// Allow remote lock/unlock from HA
    var remoteLockEnabled: Bool = true

    /// Current remote lock state (managed by HA)
    var isRemotelyLocked: Bool = false

    /// Maximum charging level (battery health - 0 = disabled)
    var maxChargingLevel: Int = 0

    /// Enable thermal throttling warnings
    var thermalThrottlingWarnings: Bool = true

    /// Report battery health metrics to HA
    var reportBatteryHealth: Bool = true

    /// Locked orientation (used for tamper detection)
    var lockedOrientation: DeviceOrientation?

    /// Expected orientation for tamper detection
    var expectedOrientation: DeviceOrientation = .landscape

    /// Enable settings export capability
    var allowSettingsExport: Bool = true
}

// MARK: - Supporting Types

public struct TimeOfDay: Codable, Equatable {
    var hour: Int
    var minute: Int

    var asDateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    func isBefore(_ other: TimeOfDay) -> Bool {
        if hour != other.hour {
            return hour < other.hour
        }
        return minute < other.minute
    }
}

public struct DashboardConfig: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var name: String
    var url: String
    var icon: String = "mdi:view-dashboard"

    /// Whether this is included in rotation
    var includeInRotation: Bool = true
}

public struct DashboardScheduleEntry: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var dashboardId: String
    var startTime: TimeOfDay
    var endTime: TimeOfDay
    var daysOfWeek: [Int] = [1, 2, 3, 4, 5, 6, 7] // 1 = Sunday
}

public struct ScheduleEntry: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var time: TimeOfDay
    var daysOfWeek: [Int] = [1, 2, 3, 4, 5, 6, 7]
    var enabled: Bool = true
}

public struct EntityTrigger: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var entityId: String
    var triggerState: String // "on", "off", "home", etc.
    var delay: TimeInterval = 0 // Debounce delay
    var enabled: Bool = true
}

public struct EntityActionTrigger: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var entityId: String
    var triggerState: String
    var action: TriggerAction
    var delay: TimeInterval = 0 // Debounce delay before action fires
    var duration: TimeInterval? // Auto-revert after this time (nil = permanent)
    var enabled: Bool = true
}

public enum TriggerAction: Codable, Equatable {
    case navigate(url: String)
    case setBrightness(level: Float)
    case startScreensaver(mode: ScreensaverMode?)
    case stopScreensaver
    case refresh
    case playSound(url: String)
    case tts(message: String)
}

public struct ClockEntityConfig: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var entityId: String
    var label: String? // Custom label (nil = use friendly name)
    var icon: String? // Custom icon (nil = use entity icon)
    var showUnit: Bool = true
}

public struct AppShortcut: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var name: String
    var urlScheme: String
    var icon: String = "mdi:application"
    var systemImage: String? // SF Symbol name (preferred over MDI)
}

public struct QuickAction: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    var name: String
    var icon: String
    var actionType: QuickActionType
}

public enum QuickActionType: Codable, Equatable {
    case haService(domain: String, service: String, data: [String: String])
    case navigate(url: String)
    case toggleEntity(entityId: String)
    case script(entityId: String)
    case scene(entityId: String)
}

// MARK: - Enums

public enum ScreensaverMode: String, Codable, CaseIterable {
    case blank = "blank"
    case dim = "dim"
    case clock = "clock"
    case clockWithEntities = "clock_entities"
    case photos = "photos"
    case photosWithClock = "photos_clock"
    case customURL = "custom_url"

    var displayName: String {
        switch self {
        case .blank: return "Blank (Black Screen)"
        case .dim: return "Dim Dashboard"
        case .clock: return "Clock"
        case .clockWithEntities: return "Clock + Sensors"
        case .photos: return "Photo Frame"
        case .photosWithClock: return "Photos + Clock"
        case .customURL: return "Custom Dashboard"
        }
    }
}

public enum ClockStyle: String, Codable, CaseIterable {
    case large = "large"
    case minimal = "minimal"
    case analog = "analog"
    case digital = "digital"

    var displayName: String {
        switch self {
        case .large: return "Large"
        case .minimal: return "Minimal"
        case .analog: return "Analog"
        case .digital: return "Digital"
        }
    }
}

public enum PhotoSource: String, Codable, CaseIterable {
    case local = "local"
    case iCloud = "icloud"
    case haMedia = "ha_media"
    case all = "all"

    var displayName: String {
        switch self {
        case .local: return "On This Device"
        case .iCloud: return "iCloud Photos"
        case .haMedia: return "Home Assistant Media"
        case .all: return "All Sources"
        }
    }
}

public enum PhotoTransition: String, Codable, CaseIterable {
    case fade = "fade"
    case slide = "slide"
    case none = "none"

    var displayName: String {
        switch self {
        case .fade: return "Fade"
        case .slide: return "Slide"
        case .none: return "None"
        }
    }
}

public enum PhotoFitMode: String, Codable, CaseIterable {
    case fill = "fill"
    case fit = "fit"

    var displayName: String {
        switch self {
        case .fill: return "Fill Screen"
        case .fit: return "Fit to Screen"
        }
    }
}

public enum MotionSensitivity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

public enum QuickLaunchGesture: String, Codable, CaseIterable {
    case swipeFromBottom = "swipe_bottom"
    case swipeFromTop = "swipe_top"
    case swipeFromLeft = "swipe_left"
    case swipeFromRight = "swipe_right"
    case doubleTap = "double_tap"
    case longPress = "long_press"

    var displayName: String {
        switch self {
        case .swipeFromBottom: return "Swipe from Bottom"
        case .swipeFromTop: return "Swipe from Top"
        case .swipeFromLeft: return "Swipe from Left"
        case .swipeFromRight: return "Swipe from Right"
        case .doubleTap: return "Double Tap"
        case .longPress: return "Long Press"
        }
    }
}

public enum OverlayPosition: String, Codable, CaseIterable {
    case top = "top"
    case bottom = "bottom"

    var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }
}

public enum OrientationLock: String, Codable, CaseIterable {
    case current = "current"
    case portrait = "portrait"
    case portraitUpsideDown = "portrait_upside_down"
    case landscape = "landscape"
    case landscapeLeft = "landscape_left"
    case landscapeRight = "landscape_right"

    var displayName: String {
        switch self {
        case .current: return "Current Orientation"
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait (Upside Down)"
        case .landscape: return "Landscape (Any)"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
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
    case away = "away"
    case background = "background"
}

public enum ScreenCorner: String, Codable, CaseIterable {
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"

    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

public enum CameraPopupSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case fullScreen = "full_screen"

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .fullScreen: return "Full Screen"
        }
    }

    /// Returns width percentage and max width in points
    var sizeParameters: (widthPercent: CGFloat, maxWidth: CGFloat, heightPercent: CGFloat) {
        switch self {
        case .small: return (0.4, 320, 0.4)
        case .medium: return (0.55, 450, 0.5)
        case .large: return (0.7, 600, 0.6)
        case .fullScreen: return (0.95, 1200, 0.9)
        }
    }
}

public enum CameraPopupPosition: String, Codable, CaseIterable {
    case center = "center"
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"

    var displayName: String {
        switch self {
        case .center: return "Center"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

public enum DeviceOrientation: String, Codable, CaseIterable {
    case portrait = "portrait"
    case portraitUpsideDown = "portrait_upside_down"
    case landscapeLeft = "landscape_left"
    case landscapeRight = "landscape_right"
    case landscape = "landscape"
    case faceUp = "face_up"
    case faceDown = "face_down"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait (Upside Down)"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .landscape: return "Landscape"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        case .unknown: return "Unknown"
        }
    }

    static func from(_ uiOrientation: UIDeviceOrientation) -> DeviceOrientation {
        switch uiOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .faceUp: return .faceUp
        case .faceDown: return .faceDown
        default: return .unknown
        }
    }

    func matches(_ other: DeviceOrientation) -> Bool {
        if self == other { return true }
        // Landscape matches both left and right
        if self == .landscape && (other == .landscapeLeft || other == .landscapeRight) {
            return true
        }
        if other == .landscape && (self == .landscapeLeft || self == .landscapeRight) {
            return true
        }
        return false
    }
}

// MARK: - Default App Shortcuts

extension AppShortcut {
    static let defaults: [AppShortcut] = [
        AppShortcut(name: "Safari", urlScheme: "x-web-search://", icon: "mdi:safari", systemImage: "safari"),
        AppShortcut(name: "Music", urlScheme: "music://", icon: "mdi:music", systemImage: "music.note"),
        AppShortcut(name: "Spotify", urlScheme: "spotify://", icon: "mdi:spotify", systemImage: nil),
        AppShortcut(name: "Settings", urlScheme: "App-prefs://", icon: "mdi:cog", systemImage: "gear"),
        AppShortcut(name: "Camera", urlScheme: "camera://", icon: "mdi:camera", systemImage: "camera"),
        AppShortcut(name: "UniFi Protect", urlScheme: "uiprotect://", icon: "mdi:shield-home", systemImage: nil),
    ]
}
