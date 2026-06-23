import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

enum KioskPushCommand: String, CaseIterable {
    case showScreensaver = "kiosk_show_screensaver"
    case hideScreensaver = "kiosk_hide_screensaver"

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
        }
    }

    var localizedSubtitle: String {
        L10n.Kiosk.PushCommand.subtitle
    }

    var screensaverCommand: KioskScreensaverCommand? {
        switch self {
        case .showScreensaver:
            return .show
        case .hideScreensaver:
            return .hide
        }
    }

    var symbol: SFSymbol {
        switch self {
        case .showScreensaver:
            return .moonStarsFill
        case .hideScreensaver:
            return .sunMaxFill
        }
    }

    var symbolForegroundStyle: (primary: Color, secondary: Color) {
        switch self {
        case .showScreensaver:
            return (.white, .indigo)
        case .hideScreensaver:
            return (.white, .orange)
        }
    }
}
