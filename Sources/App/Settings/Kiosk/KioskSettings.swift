import Foundation
import GRDB

public struct KioskSettings: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static let kioskSettingsId = "kiosk-settings"

    public var id: String
    public var enabled: Bool
    public var requireAuthentication: Bool
    public var acceptRemoteCommands: Bool
    public var serverId: String?
    public var dashboard: String?
    public var keepScreenOn: Bool
    public var removeHeaderAndSidebar: Bool
    public var hideStatusBar: Bool
    public var autoReload: KioskAutoReloadInterval
    public var settingsEntryPosition: KioskCornerPosition
    public var screensaver: KioskScreensaverSettings

    public init(
        id: String = KioskSettings.kioskSettingsId,
        enabled: Bool = false,
        requireAuthentication: Bool = false,
        acceptRemoteCommands: Bool = true,
        serverId: String? = nil,
        dashboard: String? = nil,
        keepScreenOn: Bool = false,
        removeHeaderAndSidebar: Bool = false,
        hideStatusBar: Bool = false,
        autoReload: KioskAutoReloadInterval = .never,
        settingsEntryPosition: KioskCornerPosition = .bottomTrailing,
        screensaver: KioskScreensaverSettings = KioskScreensaverSettings()
    ) {
        self.id = id
        self.enabled = enabled
        self.requireAuthentication = requireAuthentication
        self.acceptRemoteCommands = acceptRemoteCommands
        self.serverId = serverId
        self.dashboard = dashboard
        self.keepScreenOn = keepScreenOn
        self.removeHeaderAndSidebar = removeHeaderAndSidebar
        self.hideStatusBar = hideStatusBar
        self.autoReload = autoReload
        self.settingsEntryPosition = settingsEntryPosition
        self.screensaver = screensaver
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? KioskSettings.kioskSettingsId
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.requireAuthentication = try container.decodeIfPresent(Bool.self, forKey: .requireAuthentication) ?? false
        self.acceptRemoteCommands = try container.decodeIfPresent(Bool.self, forKey: .acceptRemoteCommands) ?? true
        self.serverId = try container.decodeIfPresent(String.self, forKey: .serverId)
        self.dashboard = try container.decodeIfPresent(String.self, forKey: .dashboard)
        self.keepScreenOn = try container.decodeIfPresent(Bool.self, forKey: .keepScreenOn) ?? false
        self.removeHeaderAndSidebar = try container.decodeIfPresent(Bool.self, forKey: .removeHeaderAndSidebar) ?? false
        self.hideStatusBar = try container.decodeIfPresent(Bool.self, forKey: .hideStatusBar) ?? false
        // Intervals under 10 minutes were removed; a stored value that no longer resolves falls back to
        // `.never` (the feature is in beta, so we don't migrate the removed values).
        self.autoReload = try container.decodeIfPresent(String.self, forKey: .autoReload)
            .flatMap(KioskAutoReloadInterval.init(rawValue:)) ?? .never
        self.settingsEntryPosition = try container.decodeIfPresent(
            KioskCornerPosition.self,
            forKey: .settingsEntryPosition
        ) ?? .bottomTrailing
        self.screensaver = try container.decodeIfPresent(
            KioskScreensaverSettings.self,
            forKey: .screensaver
        ) ?? KioskScreensaverSettings()
    }

    public static func current() throws -> KioskSettings? {
        try Current.database().read { db in
            try KioskSettings.fetchOne(db)
        }
    }
}

public struct KioskScreensaverSettings: Codable, Equatable {
    public var enabled: Bool
    public var mode: KioskScreensaverMode
    public var clockStyle: KioskClockStyle
    public var showDate: Bool
    public var showSeconds: Bool
    public var timeToStart: KioskScreensaverTimeout
    public var dimEnabled: Bool
    public var dimLevel: Double
    public var pixelShiftEnabled: Bool

    public init(
        enabled: Bool = false,
        mode: KioskScreensaverMode = .clock,
        clockStyle: KioskClockStyle = .large,
        showDate: Bool = true,
        showSeconds: Bool = false,
        timeToStart: KioskScreensaverTimeout = .minutes5,
        dimEnabled: Bool = false,
        dimLevel: Double = 0.1,
        pixelShiftEnabled: Bool = false
    ) {
        self.enabled = enabled
        self.mode = mode
        self.clockStyle = clockStyle
        self.showDate = showDate
        self.showSeconds = showSeconds
        self.timeToStart = timeToStart
        self.dimEnabled = dimEnabled
        self.dimLevel = dimLevel
        self.pixelShiftEnabled = pixelShiftEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.mode = try container.decodeIfPresent(KioskScreensaverMode.self, forKey: .mode) ?? .clock
        self.clockStyle = try container.decodeIfPresent(KioskClockStyle.self, forKey: .clockStyle) ?? .large
        self.showDate = try container.decodeIfPresent(Bool.self, forKey: .showDate) ?? true
        self.showSeconds = try container.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? false
        self.timeToStart = try container.decodeIfPresent(
            KioskScreensaverTimeout.self,
            forKey: .timeToStart
        ) ?? .minutes5
        self.dimEnabled = try container.decodeIfPresent(Bool.self, forKey: .dimEnabled) ?? false
        self.dimLevel = try container.decodeIfPresent(Double.self, forKey: .dimLevel) ?? 0.1
        self.pixelShiftEnabled = try container.decodeIfPresent(Bool.self, forKey: .pixelShiftEnabled) ?? false
    }
}

public enum KioskAutoReloadInterval: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case never
    case minutes10
    case minutes15
    case minutes30
    case hours1

    public var id: String { rawValue }

    public var timeInterval: TimeInterval? {
        switch self {
        case .never: return nil
        case .minutes10: return 10 * 60
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hours1: return 60 * 60
        }
    }

    public var title: String {
        switch self {
        case .never: return L10n.Kiosk.AutoReload.never
        case .minutes10: return L10n.Kiosk.AutoReload.minutes10
        case .minutes15: return L10n.Kiosk.AutoReload.minutes15
        case .minutes30: return L10n.Kiosk.AutoReload.minutes30
        case .hours1: return L10n.Kiosk.AutoReload.hours1
        }
    }
}

public enum KioskScreensaverMode: String, Codable, CaseIterable, Identifiable {
    case clock
    case dim
    case blank

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clock: return L10n.Kiosk.Screensaver.Mode.clock
        case .dim: return L10n.Kiosk.Screensaver.Mode.dim
        case .blank: return L10n.Kiosk.Screensaver.Mode.blank
        }
    }
}

public enum KioskClockStyle: String, Codable, CaseIterable, Identifiable {
    case large
    case medium
    case small

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .large: return L10n.Kiosk.Screensaver.ClockStyle.large
        case .medium: return L10n.Kiosk.Screensaver.ClockStyle.medium
        case .small: return L10n.Kiosk.Screensaver.ClockStyle.small
        }
    }
}

public enum KioskScreensaverTimeout: String, Codable, CaseIterable, Identifiable {
    case seconds30
    case minutes1
    case minutes5
    case minutes10
    case minutes15
    case minutes30
    case hours1
    case pushNotificationControlled

    public var id: String { rawValue }

    public var timeInterval: TimeInterval? {
        switch self {
        case .seconds30: return 30
        case .minutes1: return 60
        case .minutes5: return 5 * 60
        case .minutes10: return 10 * 60
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hours1: return 60 * 60
        case .pushNotificationControlled: return nil
        }
    }

    public var title: String {
        switch self {
        case .seconds30: return L10n.Kiosk.Screensaver.Timeout.seconds30
        case .minutes1: return L10n.Kiosk.Screensaver.Timeout.minutes1
        case .minutes5: return L10n.Kiosk.Screensaver.Timeout.minutes5
        case .minutes10: return L10n.Kiosk.Screensaver.Timeout.minutes10
        case .minutes15: return L10n.Kiosk.Screensaver.Timeout.minutes15
        case .minutes30: return L10n.Kiosk.Screensaver.Timeout.minutes30
        case .hours1: return L10n.Kiosk.Screensaver.Timeout.hours1
        case .pushNotificationControlled: return L10n.Kiosk.Screensaver.Timeout.pushNotificationControlled
        }
    }
}

public enum KioskCornerPosition: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .topLeading: return L10n.Kiosk.Corner.topLeading
        case .topTrailing: return L10n.Kiosk.Corner.topTrailing
        case .bottomLeading: return L10n.Kiosk.Corner.bottomLeading
        case .bottomTrailing: return L10n.Kiosk.Corner.bottomTrailing
        }
    }
}
