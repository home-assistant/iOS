import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

enum KioskPushCommand: String, CaseIterable {
    case showScreensaver = "kiosk_show_screensaver"
    case hideScreensaver = "kiosk_hide_screensaver"
    case showCamera = "kiosk_show_camera"
    case hideCamera = "kiosk_hide_camera"
    case setBrightness = "kiosk_set_brightness"
    case setVolume = "kiosk_set_volume"
    case reload = "kiosk_reload"

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

    /// The payload key holding this command's numeric level, for commands that take one.
    var levelKey: String? {
        switch self {
        case .setBrightness:
            return "level"
        case .setVolume:
            return "volume"
        case .showScreensaver, .hideScreensaver, .showCamera, .hideCamera, .reload:
            return nil
        }
    }

    /// The command's level from the payload, normalized to `0...1`. Accepts a fraction (`0...1`) or a
    /// percentage (`1...100`), as a number or numeric string, at the top level or under `homeassistant`.
    func level(from userInfo: [AnyHashable: Any]?) -> Float? {
        guard let levelKey, let userInfo,
              let raw = Self.numericValue(forKey: levelKey, in: userInfo) else {
            return nil
        }
        let fraction = raw > 1 ? raw / 100 : raw
        return Float(min(max(fraction, 0), 1))
    }

    private static func numericValue(forKey key: String, in userInfo: [AnyHashable: Any]) -> Double? {
        if let value = numericValue(userInfo[key]) {
            return value
        }
        if let homeassistant = userInfo["homeassistant"] as? [String: Any],
           let value = numericValue(homeassistant[key]) {
            return value
        }
        if let homeassistant = userInfo["homeassistant"] as? [AnyHashable: Any],
           let value = numericValue(homeassistant[key]) {
            return value
        }
        return nil
    }

    private static func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
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
        case .setBrightness:
            return L10n.Kiosk.PushCommand.setBrightness
        case .setVolume:
            return L10n.Kiosk.PushCommand.setVolume
        case .reload:
            return L10n.Kiosk.PushCommand.reload
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
        case .setBrightness:
            return .sunMax
        case .setVolume:
            return .speakerWave3Fill
        case .reload:
            return .arrowClockwise
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
        case .setBrightness:
            return (.white, .yellow)
        case .setVolume:
            return (.white, .teal)
        case .reload:
            return (.white, .green)
        }
    }
}
