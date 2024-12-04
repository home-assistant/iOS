import Foundation
import UIKit

public enum Domain: String, CaseIterable {
    case button
    case cover
    case inputBoolean = "input_boolean"
    case inputButton = "input_button"
    case light
    case lock
    case scene
    case script
    case `switch`
    case sensor
    case binarySensor = "binary_sensor"
    case zone
    case person
    // TODO: Map more domains

    public enum State: String {
        case locked
        case unlocked
        case jammed
        case locking
        case unlocking

        case on
        case off

        case opening
        case closing
        case closed
        case open

        case unknown
        case unavailable
    }

    public var states: [State] {
        var states: [State] = []
        switch self {
        case .cover:
            states = [.open, .closed, .opening, .closing]
        case .light:
            states = [.on, .off]
        case .lock:
            states = [.locked, .unlocked, .jammed, .locking, .unlocking]
        case .switch:
            states = [.on, .off]
        default:
            states = []
        }

        states.append(contentsOf: [.unavailable, .unknown])
        return states
    }

    public var icon: MaterialDesignIcons {
        var image = MaterialDesignIcons.bookmarkIcon
        switch self {
        case .button:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .cover:
            image = MaterialDesignIcons.curtainsIcon
        case .inputBoolean:
            image = MaterialDesignIcons.toggleSwitchOutlineIcon
        case .inputButton:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .light:
            image = MaterialDesignIcons.lightbulbIcon
        case .lock:
            image = MaterialDesignIcons.lockIcon
        case .scene:
            image = MaterialDesignIcons.paletteOutlineIcon
        case .script:
            image = MaterialDesignIcons.scriptTextOutlineIcon
        case .switch:
            image = MaterialDesignIcons.lightSwitchIcon
        case .sensor:
            image = MaterialDesignIcons.eyeIcon
        case .binarySensor:
            image = MaterialDesignIcons.eyeIcon
        case .zone:
            image = MaterialDesignIcons.mapIcon
        case .person:
            image = MaterialDesignIcons.accountIcon
        }
        return image
    }

    public var localizedDescription: String {
        CoreStrings.getDomainLocalizedTitle(domain: self)
    }

    public var isCarPlaySupported: Bool {
        carPlaySupportedDomains.contains(self)
    }

    public func localizedState(for state: String) -> String {
        switch self {
        case .button, .inputButton, .scene:
            if let relativeDate = isoDateToRelativeTimeString(state) {
                return relativeDate
            }
        default:
            break
        }
        return CoreStrings.getDomainStateLocalizedTitle(state: state) ?? FrontendStrings
            .getDefaultStateLocalizedTitle(state: state) ?? state
    }

    private func isoDateToRelativeTimeString(_ isoDateString: String) -> String? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = dateFormatter.date(from: isoDateString) else {
            return nil
        }

        let relativeFormatter = RelativeDateTimeFormatter()
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - CarPlay

public extension Domain {
    var carPlaySupportedDomains: [Domain] {
        [
            .button,
            .cover,
            .inputBoolean,
            .inputButton,
            .light,
            .lock,
            .scene,
            .script,
            .switch,
        ]
    }
}
