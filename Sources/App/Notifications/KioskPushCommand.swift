import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

enum KioskPushCommand: String, CaseIterable {
    case showScreensaver = "kiosk_show_screensaver"
    case hideScreensaver = "kiosk_hide_screensaver"
    case showCamera = "kiosk_show_camera"
    case hideCamera = "kiosk_hide_camera"
    case reload = "kiosk_reload"
    case defaultDashboard = "kiosk_default"

    static let prefix = "kiosk_"

    static func isKioskCommand(message: String) -> Bool {
        normalized(message).hasPrefix(prefix)
    }

    init?(message: String) {
        self.init(rawValue: Self.normalized(message))
    }

    private static func normalized(_ message: String) -> String {
        message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var localizedString: String {
        switch self {
        case .showScreensaver:
            return L10n.Kiosk.PushCommand.showScreensaver
        case .hideScreensaver:
            return L10n.Kiosk.PushCommand.hideScreensaver
        case .showCamera:
            return L10n.Kiosk.PushCommand.showCamera
        case .hideCamera:
            return L10n.Kiosk.PushCommand.hideCamera
        case .reload:
            return L10n.Kiosk.PushCommand.reload
        case .defaultDashboard:
            return L10n.Kiosk.PushCommand.defaultDashboard
        }
    }

    var localizedSubtitle: String {
        L10n.Kiosk.PushCommand.subtitle
    }

    var symbol: SFSymbol {
        switch self {
        case .showScreensaver:
            return .moonStarsFill
        case .hideScreensaver:
            return .sunMaxFill
        case .showCamera:
            return .videoFill
        case .hideCamera:
            return .videoSlashFill
        case .reload:
            return .arrowClockwise
        case .defaultDashboard:
            return .houseFill
        }
    }

    var symbolForegroundStyle: (primary: Color, secondary: Color) {
        switch self {
        case .showScreensaver:
            return (.white, .indigo)
        case .hideScreensaver:
            return (.white, .orange)
        case .showCamera:
            return (.white, .blue)
        case .hideCamera:
            return (.white, .gray)
        case .reload:
            return (.white, .green)
        case .defaultDashboard:
            return (.white, .teal)
        }
    }
}
