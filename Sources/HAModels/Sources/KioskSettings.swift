import Foundation
import GRDB

/// Kiosk mode configuration (single row). Pure, extension-safe model (Foundation + GRDB only);
/// localized titles and the `Current.database()`-backed queries live in extensions in the app.
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
    public var settingsEntryBackgroundColor: String?
    public var settingsEntryIconColor: String?
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
        settingsEntryBackgroundColor: String? = nil,
        settingsEntryIconColor: String? = nil,
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
        self.settingsEntryBackgroundColor = settingsEntryBackgroundColor
        self.settingsEntryIconColor = settingsEntryIconColor
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
        self.autoReload = try container.decodeIfPresent(String.self, forKey: .autoReload)
            .flatMap(KioskAutoReloadInterval.init(rawValue:)) ?? .never
        self.settingsEntryPosition = try container.decodeIfPresent(
            KioskCornerPosition.self,
            forKey: .settingsEntryPosition
        ) ?? .bottomTrailing
        self.settingsEntryBackgroundColor = try container.decodeIfPresent(
            String.self,
            forKey: .settingsEntryBackgroundColor
        )
        self.settingsEntryIconColor = try container.decodeIfPresent(String.self, forKey: .settingsEntryIconColor)
        self.screensaver = try container.decodeIfPresent(
            KioskScreensaverSettings.self,
            forKey: .screensaver
        ) ?? KioskScreensaverSettings()
    }
}

public struct KioskScreensaverSettings: Codable, Equatable {
    public var enabled: Bool
    public var mode: KioskScreensaverMode
    public var showDate: Bool
    public var showSeconds: Bool
    public var timeToStart: KioskScreensaverTimeout
    public var dimEnabled: Bool
    public var dimLevel: Double
    public var pixelShiftEnabled: Bool
    public var clockFontWeight: Double
    public var dateFontWeight: Double
    public var clockFontSize: Double
    public var dateFontSize: Double

    public init(
        enabled: Bool = false,
        mode: KioskScreensaverMode = .clock,
        showDate: Bool = true,
        showSeconds: Bool = false,
        timeToStart: KioskScreensaverTimeout = .minutes5,
        dimEnabled: Bool = false,
        dimLevel: Double = 0.1,
        pixelShiftEnabled: Bool = false,
        clockFontWeight: Double = 0.15,
        dateFontWeight: Double = 0.4,
        clockFontSize: Double = 0.5,
        dateFontSize: Double = 0.5
    ) {
        self.enabled = enabled
        self.mode = mode
        self.showDate = showDate
        self.showSeconds = showSeconds
        self.timeToStart = timeToStart
        self.dimEnabled = dimEnabled
        self.dimLevel = dimLevel
        self.pixelShiftEnabled = pixelShiftEnabled
        self.clockFontWeight = clockFontWeight
        self.dateFontWeight = dateFontWeight
        self.clockFontSize = clockFontSize
        self.dateFontSize = dateFontSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.mode = try container.decodeIfPresent(KioskScreensaverMode.self, forKey: .mode) ?? .clock
        self.showDate = try container.decodeIfPresent(Bool.self, forKey: .showDate) ?? true
        self.showSeconds = try container.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? false
        self.timeToStart = try container.decodeIfPresent(
            KioskScreensaverTimeout.self,
            forKey: .timeToStart
        ) ?? .minutes5
        self.dimEnabled = try container.decodeIfPresent(Bool.self, forKey: .dimEnabled) ?? false
        self.dimLevel = try container.decodeIfPresent(Double.self, forKey: .dimLevel) ?? 0.1
        self.pixelShiftEnabled = try container.decodeIfPresent(Bool.self, forKey: .pixelShiftEnabled) ?? false
        self.clockFontWeight = try container.decodeIfPresent(Double.self, forKey: .clockFontWeight) ?? 0.15
        self.dateFontWeight = try container.decodeIfPresent(Double.self, forKey: .dateFontWeight) ?? 0.4
        if let clockFontSize = try container.decodeIfPresent(Double.self, forKey: .clockFontSize) {
            self.clockFontSize = clockFontSize
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let legacyStyle = try legacy.decodeIfPresent(KioskClockStyle.self, forKey: .clockStyle)
            self.clockFontSize = legacyStyle?.legacyNormalizedFontSize ?? 0.5
        }
        self.dateFontSize = try container.decodeIfPresent(Double.self, forKey: .dateFontSize) ?? 0.5
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case clockStyle
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
}

public enum KioskScreensaverMode: String, Codable, CaseIterable, Identifiable {
    case clock
    case dim
    case blank

    public var id: String { rawValue }
}

public enum KioskClockStyle: String, Codable, CaseIterable, Identifiable {
    case large
    case medium
    case small

    public var id: String { rawValue }

    // Maps the legacy discrete style onto the normalized clock font size slider (40...200pt range).
    var legacyNormalizedFontSize: Double {
        switch self {
        case .large: return 0.5
        case .medium: return 0.275
        case .small: return 0.1
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
}

public enum KioskCornerPosition: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    public var id: String { rawValue }
}
