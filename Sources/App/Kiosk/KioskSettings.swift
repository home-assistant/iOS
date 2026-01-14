import Foundation
import UIKit

// MARK: - Main Settings Container

/// Complete settings model for kiosk mode
/// All settings are Codable for persistence and HA integration sync
public struct KioskSettings: Codable, Equatable {
    // MARK: - Core Kiosk Mode

    /// Whether kiosk mode is currently enabled
    public var isKioskModeEnabled: Bool = false

    /// Whether biometric (Face ID/Touch ID) is required to exit kiosk mode
    public var allowBiometricExit: Bool = false

    /// Whether device passcode is required as fallback to exit
    public var allowDevicePasscodeExit: Bool = false

    /// Lock navigation (disable back gestures, pull-to-refresh, etc.)
    public var navigationLockdown: Bool = true

    /// Hide iOS status bar for full immersion
    public var hideStatusBar: Bool = true

    /// Prevent iOS from auto-locking the screen
    public var preventAutoLock: Bool = true

    /// Prevent accidental edge touches
    public var edgeProtection: Bool = false

    /// Edge protection inset in points
    public var edgeProtectionInset: CGFloat = 20

    // MARK: - Dashboard Configuration

    /// Primary dashboard URL/path
    public var primaryDashboardURL: String = ""

    /// Enable native HA kiosk mode (hides sidebar/header, requires HA 2026.1+)
    public var nativeDashboardKioskMode: Bool = false

    /// Append ?kiosk to dashboard URLs (for kiosk-mode HACS integration)
    public var appendHACSKioskParameter: Bool = false

    /// All configured dashboards
    public var dashboards: [DashboardConfig] = []

    /// Dashboard schedule entries
    public var dashboardSchedule: [DashboardScheduleEntry] = []

    /// Enable dashboard rotation
    public var rotationEnabled: Bool = false

    /// Rotation interval in seconds
    public var rotationInterval: TimeInterval = 60

    /// Pause rotation when user touches screen
    public var pauseRotationOnTouch: Bool = true

    /// Resume rotation after this many seconds of idle
    public var resumeRotationAfterIdle: TimeInterval = 30

    // MARK: - Auto Refresh

    /// Legacy: Enable automatic refresh (kept for backwards compatibility)
    /// Now controlled by autoRefreshInterval > 0
    public var autoRefreshEnabled: Bool = true

    /// Periodic refresh interval in seconds (0 = never)
    public var autoRefreshInterval: TimeInterval = 0

    /// Refresh when waking from screensaver/dim
    public var refreshOnWake: Bool = true

    /// Refresh when network reconnects
    public var refreshOnNetworkReconnect: Bool = true

    /// Refresh when HA WebSocket reconnects
    public var refreshOnHAReconnect: Bool = true

    // MARK: - Brightness Control

    /// Enable brightness management
    public var brightnessControlEnabled: Bool = true

    /// Manual brightness level (0.0 - 1.0)
    public var manualBrightness: Float = 0.8

    /// Enable day/night brightness schedule
    public var brightnessScheduleEnabled: Bool = false

    /// Daytime brightness level (0.0 - 1.0)
    public var dayBrightness: Float = 0.8

    /// Nighttime brightness level (0.0 - 1.0)
    public var nightBrightness: Float = 0.3

    /// Time when day brightness starts (hour, minute)
    public var dayStartTime: TimeOfDay = .init(hour: 7, minute: 0)

    /// Time when night brightness starts (hour, minute)
    public var nightStartTime: TimeOfDay = .init(hour: 22, minute: 0)

    // MARK: - Screensaver

    /// Enable screensaver
    public var screensaverEnabled: Bool = true

    /// Screensaver mode
    public var screensaverMode: ScreensaverMode = .clock

    /// Seconds of idle before screensaver activates
    public var screensaverTimeout: TimeInterval = 300 // 5 minutes

    /// Brightness level when dimmed (0.0 - 1.0) - used when schedule is disabled
    public var screensaverDimLevel: Float = 0.1

    /// Enable day/night screensaver brightness schedule (uses same times as main brightness)
    public var screensaverBrightnessScheduleEnabled: Bool = false

    /// Daytime screensaver brightness level (0.0 - 1.0)
    public var screensaverDayDimLevel: Float = 0.15

    /// Nighttime screensaver brightness level (0.0 - 1.0)
    public var screensaverNightDimLevel: Float = 0.05

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

    /// HA entities to display on clock screensaver
    public var clockEntities: [ClockEntityConfig] = []

    // MARK: - Screensaver Weather

    /// Show weather on screensaver
    public var clockShowWeather: Bool = false

    /// Weather entity to display (e.g., weather.home)
    public var clockWeatherEntity: String = ""

    /// Temperature entity for more accurate temp display (optional, e.g., sensor.outdoor_temperature)
    public var clockTemperatureEntity: String = ""

    // MARK: - Screensaver Photos

    /// Photo source for screensaver
    public var photoSource: PhotoSource = .local

    /// Selected local photo album identifiers
    public var localPhotoAlbums: [String] = []

    /// iCloud shared album identifiers
    public var iCloudAlbums: [String] = []

    /// HA Media Browser path for photos
    public var haMediaPath: String = ""

    /// Photo display interval in seconds
    public var photoInterval: TimeInterval = 30

    /// Photo transition style
    public var photoTransition: PhotoTransition = .fade

    /// Photo fit mode (fill or fit)
    public var photoFitMode: PhotoFitMode = .fill

    /// Show clock overlay on photos
    public var photoShowClockOverlay: Bool = true

    /// Show entity data overlay on photos
    public var photoShowEntityOverlay: Bool = false

    // MARK: - Screensaver Custom URL

    /// Custom URL to load as screensaver (e.g., a minimal HA dashboard)
    public var screensaverCustomURL: String = ""

    // MARK: - Wake/Sleep Triggers

    /// Wake screen on touch
    public var wakeOnTouch: Bool = true

    /// Wake screen on camera motion detection
    public var wakeOnCameraMotion: Bool = false

    /// Wake screen on camera presence/face detection
    public var wakeOnCameraPresence: Bool = false

    /// External HA entities that trigger wake
    public var wakeEntities: [EntityTrigger] = []

    /// External HA entities that trigger sleep
    public var sleepEntities: [EntityTrigger] = []

    /// Wake schedule entries
    public var wakeSchedule: [ScheduleEntry] = []

    /// Sleep schedule entries
    public var sleepSchedule: [ScheduleEntry] = []

    // MARK: - Entity Action Triggers

    /// Entity state changes that trigger actions
    public var entityTriggers: [EntityActionTrigger] = []

    // MARK: - Camera & Presence Detection

    /// Enable camera-based motion detection
    public var cameraMotionEnabled: Bool = false

    /// Motion detection sensitivity
    public var cameraMotionSensitivity: MotionSensitivity = .medium

    /// Enable person presence detection (Vision framework)
    public var cameraPresenceEnabled: Bool = false

    /// Enable face detection (more accurate than presence)
    public var cameraFaceDetectionEnabled: Bool = false

    /// Report motion to HA as sensor
    public var reportMotionToHA: Bool = true

    /// Report presence to HA as sensor
    public var reportPresenceToHA: Bool = true

    // MARK: - Camera Popup

    /// Camera popup size when showing doorbell/security cameras
    public var cameraPopupSize: CameraPopupSize = .large

    /// Camera popup position on screen
    public var cameraPopupPosition: CameraPopupPosition = .center

    // MARK: - Audio

    /// Enable TTS announcements
    public var ttsEnabled: Bool = true

    /// TTS volume (0.0 - 1.0)
    public var ttsVolume: Float = 0.7

    /// Enable audio alerts for critical events
    public var audioAlertsEnabled: Bool = true

    /// Enable ambient audio level detection
    public var ambientAudioDetectionEnabled: Bool = false

    // MARK: - Status Overlay

    /// Show status overlay bar
    public var statusOverlayEnabled: Bool = true

    /// Status overlay position
    public var statusOverlayPosition: OverlayPosition = .top

    /// Show connection status indicator
    public var showConnectionStatus: Bool = true

    /// Show current time
    public var showTime: Bool = false

    /// Show battery indicator
    public var showBattery: Bool = true

    /// HA entities to show in status overlay
    public var statusOverlayEntities: [String] = []

    /// Auto-hide overlay after seconds (0 = always visible)
    public var statusOverlayAutoHide: TimeInterval = 5

    // MARK: - Quick Actions

    /// Enable quick actions bar
    public var quickActionsEnabled: Bool = false

    /// Quick action gesture to reveal
    public var quickActionsGesture: QuickLaunchGesture = .swipeFromRight

    /// Configured quick actions
    public var quickActions: [QuickAction] = []

    // MARK: - Device & Security

    /// Orientation lock setting
    public var orientationLock: OrientationLock = .current

    /// Enable tamper detection (orientation change alerts)
    public var tamperDetectionEnabled: Bool = false

    /// Enable touch feedback sounds
    public var touchSoundEnabled: Bool = false

    /// Enable touch haptic feedback
    public var touchHapticEnabled: Bool = true

    /// Auto-restart app on crash
    public var autoRestartOnCrash: Bool = true

    /// Low battery alert threshold (0-100, 0 = disabled)
    public var lowBatteryAlertThreshold: Int = 20

    /// Report thermal state to HA
    public var reportThermalState: Bool = true

    // MARK: - Secret Exit Gesture

    /// Enable secret gesture to access kiosk settings (escape hatch)
    public var secretExitGestureEnabled: Bool = true

    /// Corner for secret exit gesture
    public var secretExitGestureCorner: ScreenCorner = .topRight

    /// Number of taps required for secret exit gesture
    public var secretExitGestureTaps: Int = 3

    // MARK: - Enhanced Security

    /// Enable Guided Access integration
    public var guidedAccessEnabled: Bool = false

    /// Allow remote lock/unlock from HA
    public var remoteLockEnabled: Bool = true

    /// Current remote lock state (managed by HA)
    public var isRemotelyLocked: Bool = false

    /// Maximum charging level (battery health - 0 = disabled)
    public var maxChargingLevel: Int = 0

    /// Enable thermal throttling warnings
    public var thermalThrottlingWarnings: Bool = true

    /// Report battery health metrics to HA
    public var reportBatteryHealth: Bool = true

    /// Locked orientation (used for tamper detection)
    public var lockedOrientation: DeviceOrientation?

    /// Expected orientation for tamper detection
    public var expectedOrientation: DeviceOrientation = .landscape

    /// Enable settings export capability
    public var allowSettingsExport: Bool = true
}

// MARK: - Supporting Types

public struct TimeOfDay: Codable, Equatable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var asDateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    public func isBefore(_ other: TimeOfDay) -> Bool {
        if hour != other.hour {
            return hour < other.hour
        }
        return minute < other.minute
    }
}

/// Dashboard configuration with stable ID for Codable persistence
public struct DashboardConfig: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var url: String
    public var icon: String
    public var includeInRotation: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        icon: String = "mdi:view-dashboard",
        includeInRotation: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
        self.includeInRotation = includeInRotation
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, url, icon, includeInRotation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(String.self, forKey: .url)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "mdi:view-dashboard"
        self.includeInRotation = try container.decodeIfPresent(Bool.self, forKey: .includeInRotation) ?? true
    }
}

/// Dashboard schedule entry with stable ID for Codable persistence
public struct DashboardScheduleEntry: Codable, Equatable, Identifiable {
    public var id: String
    public var dashboardId: String
    public var startTime: TimeOfDay
    public var endTime: TimeOfDay
    public var daysOfWeek: [Int]

    public init(
        id: String = UUID().uuidString,
        dashboardId: String,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        daysOfWeek: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) {
        self.id = id
        self.dashboardId = dashboardId
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
    }

    private enum CodingKeys: String, CodingKey {
        case id, dashboardId, startTime, endTime, daysOfWeek
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.dashboardId = try container.decode(String.self, forKey: .dashboardId)
        self.startTime = try container.decode(TimeOfDay.self, forKey: .startTime)
        self.endTime = try container.decode(TimeOfDay.self, forKey: .endTime)
        self.daysOfWeek = try container.decodeIfPresent([Int].self, forKey: .daysOfWeek) ?? [1, 2, 3, 4, 5, 6, 7]
    }
}

/// Schedule entry with stable ID for Codable persistence
public struct ScheduleEntry: Codable, Equatable, Identifiable {
    public var id: String
    public var time: TimeOfDay
    public var daysOfWeek: [Int]
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        time: TimeOfDay,
        daysOfWeek: [Int] = [1, 2, 3, 4, 5, 6, 7],
        enabled: Bool = true
    ) {
        self.id = id
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, time, daysOfWeek, enabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.time = try container.decode(TimeOfDay.self, forKey: .time)
        self.daysOfWeek = try container.decodeIfPresent([Int].self, forKey: .daysOfWeek) ?? [1, 2, 3, 4, 5, 6, 7]
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// Entity trigger with stable ID for Codable persistence
public struct EntityTrigger: Codable, Equatable, Identifiable {
    public var id: String
    public var entityId: String
    public var triggerState: String
    public var delay: TimeInterval
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        entityId: String,
        triggerState: String,
        delay: TimeInterval = 0,
        enabled: Bool = true
    ) {
        self.id = id
        self.entityId = entityId
        self.triggerState = triggerState
        self.delay = delay
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, entityId, triggerState, delay, enabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.entityId = try container.decode(String.self, forKey: .entityId)
        self.triggerState = try container.decode(String.self, forKey: .triggerState)
        self.delay = try container.decodeIfPresent(TimeInterval.self, forKey: .delay) ?? 0
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// Entity action trigger with stable ID for Codable persistence
public struct EntityActionTrigger: Codable, Equatable, Identifiable {
    public var id: String
    public var entityId: String
    public var triggerState: String
    public var action: TriggerAction
    public var delay: TimeInterval
    public var duration: TimeInterval?
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        entityId: String,
        triggerState: String,
        action: TriggerAction,
        delay: TimeInterval = 0,
        duration: TimeInterval? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.entityId = entityId
        self.triggerState = triggerState
        self.action = action
        self.delay = delay
        self.duration = duration
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, entityId, triggerState, action, delay, duration, enabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.entityId = try container.decode(String.self, forKey: .entityId)
        self.triggerState = try container.decode(String.self, forKey: .triggerState)
        self.action = try container.decode(TriggerAction.self, forKey: .action)
        self.delay = try container.decodeIfPresent(TimeInterval.self, forKey: .delay) ?? 0
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// Describes an action that can be performed when an EntityActionTrigger fires
public enum TriggerAction: Codable, Equatable {
    /// Navigate the kiosk web view to a specific URL
    case navigate(url: String)
    /// Set the device screen brightness (0.0 to 1.0)
    case setBrightness(level: Float)
    /// Start the screensaver with optional mode
    case startScreensaver(mode: ScreensaverMode?)
    /// Stop any active screensaver
    case stopScreensaver
    /// Reload the current kiosk web view
    case refresh
    /// Play an audio file from URL
    case playSound(url: String)
    /// Speak a text message using text-to-speech
    case tts(message: String)
}

/// Clock entity configuration with stable ID for Codable persistence
public struct ClockEntityConfig: Codable, Equatable, Identifiable {
    public var id: String
    public var entityId: String
    public var label: String?
    public var icon: String?
    public var showUnit: Bool
    public var displayFormat: EntityDisplayFormat
    public var decimalPlaces: Int?
    public var prefix: String?
    public var suffix: String?

    public init(
        id: String = UUID().uuidString,
        entityId: String,
        label: String? = nil,
        icon: String? = nil,
        showUnit: Bool = true,
        displayFormat: EntityDisplayFormat = .auto,
        decimalPlaces: Int? = nil,
        prefix: String? = nil,
        suffix: String? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.label = label
        self.icon = icon
        self.showUnit = showUnit
        self.displayFormat = displayFormat
        self.decimalPlaces = decimalPlaces
        self.prefix = prefix
        self.suffix = suffix
    }

    private enum CodingKeys: String, CodingKey {
        case id, entityId, label, icon, showUnit, displayFormat, decimalPlaces, prefix, suffix
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.entityId = try container.decode(String.self, forKey: .entityId)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.showUnit = try container.decodeIfPresent(Bool.self, forKey: .showUnit) ?? true
        self.displayFormat = try container.decodeIfPresent(EntityDisplayFormat.self, forKey: .displayFormat) ?? .auto
        self.decimalPlaces = try container.decodeIfPresent(Int.self, forKey: .decimalPlaces)
        self.prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        self.suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
    }
}

public enum EntityDisplayFormat: String, Codable, CaseIterable {
    case auto = "auto"
    case value = "value"
    case valueWithUnit = "value_unit"
    case valueSpaceUnit = "value_space_unit"
    case integer = "integer"
    case percentage = "percentage"
    case compact = "compact"
    case time = "time"

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .value: return "Value Only"
        case .valueWithUnit: return "Value + Unit"
        case .valueSpaceUnit: return "Value (space) Unit"
        case .integer: return "Integer"
        case .percentage: return "Percentage"
        case .compact: return "Compact"
        case .time: return "Duration"
        }
    }
}

/// Quick action configuration with stable ID for Codable persistence
public struct QuickAction: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var icon: String
    public var actionType: QuickActionType

    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        actionType: QuickActionType
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.actionType = actionType
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, actionType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.icon = try container.decode(String.self, forKey: .icon)
        self.actionType = try container.decode(QuickActionType.self, forKey: .actionType)
    }
}

/// Type of action that can be triggered from a kiosk quick action button
public enum QuickActionType: Codable, Equatable {
    /// Call a Home Assistant service
    /// - Parameters:
    ///   - domain: Service domain (e.g., "light", "script", "scene")
    ///   - service: Service name (e.g., "turn_on", "toggle")
    ///   - data: Key-value payload for the service call
    case haService(domain: String, service: String, data: [String: String])

    /// Navigate the kiosk to a specific URL
    case navigate(url: String)

    /// Toggle the state of an entity
    case toggleEntity(entityId: String)

    /// Run a Home Assistant script
    case script(entityId: String)

    /// Activate a Home Assistant scene
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public var displayName: String {
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
    case background = "background"
}

public enum ScreenCorner: String, Codable, CaseIterable {
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"

    public var displayName: String {
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

    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .fullScreen: return "Full Screen"
        }
    }

    public var sizeParameters: (widthPercent: CGFloat, maxWidth: CGFloat, heightPercent: CGFloat) {
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

    public var displayName: String {
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

    public var displayName: String {
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

    public static func from(_ uiOrientation: UIDeviceOrientation) -> DeviceOrientation {
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

    public func matches(_ other: DeviceOrientation) -> Bool {
        if self == other { return true }
        if self == .landscape, other == .landscapeLeft || other == .landscapeRight {
            return true
        }
        if other == .landscape, self == .landscapeLeft || self == .landscapeRight {
            return true
        }
        return false
    }
}
