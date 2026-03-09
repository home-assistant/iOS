import Foundation
import HAKit
import UIKit

public enum Domain: String, CaseIterable {
    case automation
    case button
    case climate
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
    case todo
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

        /// States that represent an "active" condition
        public var isActive: Bool {
            Domain.activeStates.contains(self)
        }
    }

    /// States that represent an "active" condition
    /// such as for displaying accent color for entity tile icon
    public static var activeStates: [State] = [
        .on,
        .open,
        .unlocked,
        .unlocking,
        .locking,
        .opening,
        .closing,
    ]

    /// States that represent a "problem" condition
    public static var problemStates: [State] = [
        .jammed,
        .unavailable,
    ]

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

    public func contextualStateDescription(for entity: HAEntity) -> String {
        let baseState = entity.localizedState.leadingCapitalized

        // Add unit of measurement if available
        if let unitOfMeasurement = entity.attributes.dictionary["unit_of_measurement"] {
            return "\(baseState) \(unitOfMeasurement)"
        }

        guard let state = Domain.State(rawValue: entity.state) else {
            return baseState
        }

        return stateForDeviceClass(entity.deviceClass, state: state)
    }

    public func stateForDeviceClass(_ deviceClass: DeviceClass, state: Domain.State) -> String {
        let baseState = localizedState(for: state.rawValue).leadingCapitalized
        // Provide context-aware descriptions for binary sensors with device classes
        if self == .binarySensor {
            switch deviceClass {
            case .door:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentDoorStateOn :
                    CoreStrings.componentBinarySensorEntityComponentDoorStateOff
            case .window:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentWindowStateOn :
                    CoreStrings.componentBinarySensorEntityComponentWindowStateOff
            case .garage, .garageDoor:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOn :
                    CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOff
            case .lock:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentLockStateOn :
                    CoreStrings.componentBinarySensorEntityComponentLockStateOff
            case .opening:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentOpeningStateOn :
                    CoreStrings.componentBinarySensorEntityComponentOpeningStateOff
            case .presence:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentPresenceStateOn :
                    CoreStrings.componentBinarySensorEntityComponentPresenceStateOff
            case .connectivity:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentConnectivityStateOn :
                    CoreStrings.componentBinarySensorEntityComponentConnectivityStateOff
            case .gate:
                // Gate uses same open/closed as door
                return state == .on ?
                    CoreStrings.commonStateOpen :
                    CoreStrings.commonStateClosed
            case .shade:
                return state == .on ?
                    CoreStrings.componentCoverEntityComponentStateOpen :
                    CoreStrings.componentCoverEntityComponentStateClosed
            default:
                // For other device classes without specific strings, use generic on/off
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentStateOn :
                    CoreStrings.componentBinarySensorEntityComponentStateOff
            }
        }

        // Provide context-aware descriptions for covers with device classes
        if self == .cover {
            switch state {
            case .open:
                return CoreStrings.componentCoverEntityComponentStateOpen
            case .closed:
                return CoreStrings.componentCoverEntityComponentStateClosed
            case .opening, .closing:
                // For transitioning states, use localized state
                return baseState
            default:
                break
            }
        }

        // Provide context for locks
        if self == .lock {
            switch state {
            case .locked:
                return CoreStrings.componentLockEntityComponentStateLocked
            case .unlocked:
                return CoreStrings.componentLockEntityComponentStateUnlocked
            case .locking, .unlocking:
                // For transitioning states, add ellipsis to show in progress
                return baseState + "..."
            case .jammed:
                // For jammed state, add exclamation to show alert
                return baseState + "!"
            default:
                break
            }
        }
        return baseState
    }

    public func icon(deviceClass: String? = nil, state: State? = nil) -> MaterialDesignIcons {
        let deviceClass = DeviceClass(rawValue: deviceClass ?? "")
        var image: MaterialDesignIcons = .bookmarkIcon
        switch self {
        case .automation:
            image = .robotIcon
        case .button:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .climate:
            image = .thermostatIcon
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
        case .todo:
            image = .checkboxMarkedOutlineIcon
        }
        return image
    }

    private func imageForCover(deviceClass: DeviceClass, state: State) -> MaterialDesignIcons {
        if state == .closed {
            switch deviceClass {
            case .garage, .garageDoor:
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
            case .garage, .garageDoor:
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
            .automation,
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

// MARK: - Main Action

public extension Domain {
    /// The primary service to call when activating this domain.
    /// Returns nil for domains that don't have a single main action (e.g., sensors).
    var mainAction: Service? {
        switch self {
        case .automation:
            return .trigger
        case .button, .inputButton:
            return .press
        case .scene, .script:
            return .turnOn
        case .cover, .fan, .inputBoolean, .light, .switch:
            return .toggle
        case .lock:
            return nil // Lock requires state-aware action (lock/unlock)
        case .sensor, .binarySensor, .zone, .person, .camera, .todo, .climate:
            return nil // Read-only or complex domains
        }
    }
}
