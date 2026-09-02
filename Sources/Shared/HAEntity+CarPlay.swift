import Foundation
import HAKit
import PromiseKit
import SwiftUI
import UIKit

public extension HAEntity {
    func onPress(for api: HomeAssistantAPI) -> Promise<Void> {
        if let domain = Domain(rawValue: domain) {
            return api.executeActionForDomainType(domain: domain, entityId: entityId, state: state)
        } else {
            Current.Log.error("Failed to parse domain for entity \(entityId)")
            return .value
        }
    }

    func getIcon() -> UIImage? {
        let image = getMDI()
        #if os(iOS)
        return image.carPlayIcon(color: stateIconColor())
        #else
        return image.image(ofSize: .init(width: 50, height: 50), color: nil)
        #endif
    }

    /// The icon color home-assistant/frontend gives this entity — its domain's, device class's and
    /// state's `--state-…` palette, or a light's own color. Shared by CarPlay and the watch so both
    /// read the same as the widgets and the frontend itself.
    ///
    /// - Parameter customColor: a color the user picked for this entity on the calling surface. As
    ///   in the frontend's tile card, it only applies while the entity is active.
    func stateIconColor(customColor: UIColor? = nil) -> UIColor? {
        UIColor(
            EntityIconColorProvider.iconColor(
                domain: domain,
                state: state.lowercased(),
                attributes: attributes.dictionary,
                customColor: customColor.map(Color.init)
            )
        )
    }

    /// Returns the appropriate icon for the entity based on its state, without applying color.
    /// This is useful when you want to apply a custom color to a state-based icon.
    ///
    /// When `componentIcons` (the backend `entity_component` map from `frontend/get_icons`) is
    /// provided, the icon is resolved the way the frontend does via `EntityIconResolver`, falling
    /// back to the app's hand-maintained mapping only when the map has nothing for the entity. With
    /// no map it keeps the legacy behavior, so callers without one are unaffected.
    func getMDI(componentIcons: EntityComponentIconsMap? = nil) -> MaterialDesignIcons {
        if let icon = attributes.icon?.normalizingIconString {
            return MaterialDesignIcons(named: icon)
        }

        let fallback = hardcodedMDI()

        if let componentIcons,
           let resolved = EntityIconResolver.icon(
               domain: domain,
               deviceClass: attributes.dictionary["device_class"] as? String,
               state: state,
               attributes: attributes.dictionary,
               map: componentIcons
           ) {
            return MaterialDesignIcons(serversideValueNamed: resolved, fallback: fallback)
        }

        return fallback
    }

    private func hardcodedMDI() -> MaterialDesignIcons {
        guard let domain = Domain(rawValue: domain) else { return .bookmarkIcon }
        switch domain {
        case .button:
            return getButtonIcon()
        case .cover:
            return getCoverIcon()
        case .inputBoolean:
            return getInputBooleanIcon()
        case .inputButton:
            return .gestureTapButtonIcon
        case .light:
            return .lightbulbIcon
        case .lock:
            return getLockIcon()
        case .scene:
            return .paletteOutlineIcon
        case .script:
            return .scriptTextOutlineIcon
        case .switch:
            return getSwitchIcon()
        case .sensor:
            return .eyeIcon
        case .binarySensor:
            return .radioboxBlankIcon
        case .zone:
            return .mapIcon
        case .person:
            return .accountIcon
        case .camera:
            return .cameraIcon
        case .fan:
            return .fanIcon
        case .automation:
            return .homeAutomationIcon
        case .todo:
            return .checkboxMarkedOutlineIcon
        case .climate:
            return .homeThermometerOutlineIcon
        default:
            return domain.icon(deviceClass: deviceClass.rawValue, state: Domain.State(rawValue: state))
        }
    }

    private func getInputBooleanIcon() -> MaterialDesignIcons {
        if !entityId.hasSuffix(".ha_ios_placeholder"), let compareState = Domain.State(rawValue: state) {
            if compareState == .on {
                return MaterialDesignIcons.checkCircleOutlineIcon
            } else {
                return MaterialDesignIcons.closeCircleOutlineIcon
            }
        } else {
            return MaterialDesignIcons.toggleSwitchOutlineIcon
        }
    }

    private func getButtonIcon() -> MaterialDesignIcons {
        switch deviceClass {
        case .restart:
            return MaterialDesignIcons.restartIcon
        case .update:
            return MaterialDesignIcons.packageUpIcon
        default:
            return MaterialDesignIcons.gestureTapButtonIcon
        }
    }

    private func getLockIcon() -> MaterialDesignIcons {
        guard let compareState = Domain.State(rawValue: state) else { return MaterialDesignIcons.lockIcon }
        switch compareState {
        case .unlocked:
            return MaterialDesignIcons.lockOpenIcon
        case .jammed:
            return MaterialDesignIcons.lockAlertIcon
        case .locking, .unlocking:
            return MaterialDesignIcons.lockClockIcon
        default:
            return MaterialDesignIcons.lockIcon
        }
    }

    private func getSwitchIcon() -> MaterialDesignIcons {
        guard let compareState = Domain.State(rawValue: state) else { return MaterialDesignIcons.lightSwitchIcon }
        if !entityId.hasSuffix(".ha_ios_placeholder") {
            let deviceClass = deviceClass
            switch deviceClass {
            case .outlet:
                return compareState == .on ? MaterialDesignIcons.powerPlugIcon : MaterialDesignIcons
                    .powerPlugOffIcon
            case .switch:
                return compareState == .on ? MaterialDesignIcons.toggleSwitchIcon : MaterialDesignIcons
                    .toggleSwitchOffIcon
            default:
                return MaterialDesignIcons.flashIcon
            }
        } else {
            return MaterialDesignIcons.lightSwitchIcon
        }
    }

    private func getCoverIcon() -> MaterialDesignIcons {
        guard let state = Domain.State(rawValue: state) else { return MaterialDesignIcons.bookmarkIcon }

        switch deviceClass {
        case .garage:
            switch state {
            case .opening:
                return MaterialDesignIcons.arrowUpBoxIcon
            case .closing:
                return MaterialDesignIcons.arrowDownBoxIcon
            case .closed:
                return MaterialDesignIcons.garageIcon
            default:
                return MaterialDesignIcons.garageOpenIcon
            }
        case .gate:
            switch state {
            case .opening: return MaterialDesignIcons.gateArrowRightIcon
            case .closed: return MaterialDesignIcons.gateIcon
            default: return MaterialDesignIcons.gateOpenIcon
            }
        case .door:
            return state == .open ? MaterialDesignIcons.doorOpenIcon : MaterialDesignIcons.doorClosedIcon
        case .damper:
            return state == .open ? MaterialDesignIcons.circleIcon : MaterialDesignIcons.circleSlice8Icon
        case .shutter:
            switch state {
            case .opening: return MaterialDesignIcons.arrowUpBoxIcon
            case .closing: return MaterialDesignIcons.arrowDownBoxIcon
            case .closed: return MaterialDesignIcons.windowShutterIcon
            default: return MaterialDesignIcons.windowShutterOpenIcon
            }
        case .curtain:
            switch state {
            case .opening: return MaterialDesignIcons.arrowSplitVerticalIcon
            case .closing: return MaterialDesignIcons.arrowCollapseHorizontalIcon
            case .closed: return MaterialDesignIcons.curtainsClosedIcon
            default: return MaterialDesignIcons.curtainsIcon
            }
        case .blind, .shade:
            switch state {
            case .opening: return MaterialDesignIcons.arrowUpBoxIcon
            case .closing: return MaterialDesignIcons.arrowDownBoxIcon
            case .closed: return MaterialDesignIcons.blindsIcon
            default: return MaterialDesignIcons.blindsOpenIcon
            }
        default:
            switch state {
            case .open: return MaterialDesignIcons.arrowUpBoxIcon
            case .closing: return MaterialDesignIcons.arrowDownBoxIcon
            case .closed: return MaterialDesignIcons.windowClosedIcon
            default: return MaterialDesignIcons.windowOpenIcon
            }
        }
    }

    var localizedState: String {
        if let domain = Domain(rawValue: domain) {
            return domain.localizedState(for: state)
        }

        return CoreStrings.getDomainStateLocalizedTitle(state: state) ?? FrontendStrings
            .getDefaultStateLocalizedTitle(state: state) ?? state
    }
}
