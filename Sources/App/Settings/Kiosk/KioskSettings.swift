import Foundation
import GRDB

// The kiosk models live in the `HAModels` package; these are their localized titles and
// database-backed helpers.
public extension KioskSettings {
    static func current() throws -> KioskSettings? {
        try Current.database().read { db in
            try KioskSettings.fetchOne(db)
        }
    }
}

public extension KioskAutoReloadInterval {
    var title: String {
        switch self {
        case .never: return L10n.Kiosk.AutoReload.never
        case .minutes10: return L10n.Kiosk.AutoReload.minutes10
        case .minutes15: return L10n.Kiosk.AutoReload.minutes15
        case .minutes30: return L10n.Kiosk.AutoReload.minutes30
        case .hours1: return L10n.Kiosk.AutoReload.hours1
        }
    }
}

public extension KioskScreensaverMode {
    var title: String {
        switch self {
        case .clock: return L10n.Kiosk.Screensaver.Mode.clock
        case .dim: return L10n.Kiosk.Screensaver.Mode.dim
        case .blank: return L10n.Kiosk.Screensaver.Mode.blank
        }
    }
}

public extension KioskClockStyle {
    var title: String {
        switch self {
        case .large: return L10n.Kiosk.Screensaver.ClockStyle.large
        case .medium: return L10n.Kiosk.Screensaver.ClockStyle.medium
        case .small: return L10n.Kiosk.Screensaver.ClockStyle.small
        }
    }
}

public extension KioskScreensaverTimeout {
    var title: String {
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

public extension KioskCornerPosition {
    var title: String {
        switch self {
        case .topLeading: return L10n.Kiosk.Corner.topLeading
        case .topTrailing: return L10n.Kiosk.Corner.topTrailing
        case .bottomLeading: return L10n.Kiosk.Corner.bottomLeading
        case .bottomTrailing: return L10n.Kiosk.Corner.bottomTrailing
        }
    }
}
