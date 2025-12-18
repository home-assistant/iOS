import Foundation
import HAKit
import UIKit

public enum Domain: String, CaseIterable {
    case button
    case cover
    case fan
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
    case camera
    // TODO: Map more domains

    public init?(entityId: String) {
        let domainString = entityId.components(separatedBy: ".").first ?? ""
        self.init(rawValue: domainString)
    }

    public enum State: String, Codable {
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
        case .fan:
            states = [.on, .off]
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

    public func icon(deviceClass: String? = nil, state: State? = nil) -> MaterialDesignIcons {
        let deviceClass = DeviceClass(rawValue: deviceClass ?? "")
        var image: MaterialDesignIcons = .bookmarkIcon
        switch self {
        case .button:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .cover:
            image = imageForCover(deviceClass: deviceClass ?? .unknown, state: state ?? .unknown)
        case .fan:
            image = .fanIcon
        case .inputBoolean:
            image = .toggleSwitchOutlineIcon
        case .inputButton:
            image = .gestureTapButtonIcon
        case .light:
            image = .lightbulbIcon
        case .lock:
            image = .lockIcon
        case .scene:
            image = .paletteOutlineIcon
        case .script:
            image = .scriptTextOutlineIcon
        case .switch:
            image = .lightSwitchIcon
        case .sensor:
            image = .eyeIcon
        case .binarySensor:
            image = .eyeIcon
        case .zone:
            image = .mapIcon
        case .person:
            image = .accountIcon
        case .camera:
            image = .cameraIcon
        }
        return image
    }

    private func imageForCover(deviceClass: DeviceClass, state: State) -> MaterialDesignIcons {
        if state == .closed {
            switch deviceClass {
            case .garage:
                return MaterialDesignIcons.garageIcon
            case .gate:
                return MaterialDesignIcons.gateIcon
            case .shutter:
                return MaterialDesignIcons.windowShutterIcon
            case .blind:
                return MaterialDesignIcons.blindsVerticalClosedIcon
            case .shade:
                return MaterialDesignIcons.rollerShadeClosedIcon
            default:
                return MaterialDesignIcons.curtainsClosedIcon
            }
        } else {
            switch deviceClass {
            case .garage:
                return MaterialDesignIcons.garageOpenIcon
            case .gate:
                return MaterialDesignIcons.gateOpenIcon
            case .shutter:
                return MaterialDesignIcons.windowShutterOpenIcon
            case .blind:
                return MaterialDesignIcons.blindsOpenIcon
            case .shade:
                return MaterialDesignIcons.rollerShadeIcon
            default:
                return MaterialDesignIcons.curtainsIcon
            }
        }
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
            .fan,
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
