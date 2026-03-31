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
        return image.carPlayIcon(color: carPlayIconColor())
        #else
        return image.image(ofSize: .init(width: 50, height: 50), color: nil)
        #endif
    }

    func carPlayIconColor(activeColorOverride: UIColor? = nil) -> UIColor? {
        guard let domain = Domain(rawValue: domain) else {
            return nil
        }

        let normalizedState = state.lowercased()
        if Domain.activeStates.map(\.rawValue).contains(normalizedState),
           let activeColorOverride {
            return activeColorOverride
        }

        return UIColor(
            EntityIconColorProvider.iconColor(
                domain: domain,
                state: normalizedState,
                colorMode: attributes.dictionary["color_mode"] as? String,
                rgbColor: parseRGBColor(from: attributes.dictionary["rgb_color"]),
                hsColor: parseHSColor(from: attributes.dictionary["hs_color"])
            )
        )
    }

    /// Returns the appropriate icon for the entity based on its state, without applying color
    /// This is useful when you want to apply a custom color to a state-based icon
    func getMDI() -> MaterialDesignIcons {
        var image = MaterialDesignIcons.bookmarkIcon

        if let icon = attributes.icon?.normalizingIconString {
            image = MaterialDesignIcons(named: icon)
        } else {
            guard let domain = Domain(rawValue: domain) else { return image }
            switch domain {
            case .button:
                image = getButtonIcon()
            case .cover:
                image = getCoverIcon()
            case .inputBoolean:
                image = getInputBooleanIcon()
            case .inputButton:
                image = .gestureTapButtonIcon
            case .light:
                image = .lightbulbIcon
            case .lock:
                image = getLockIcon()
            case .scene:
                image = .paletteOutlineIcon
            case .script:
                image = .scriptTextOutlineIcon
            case .switch:
                image = getSwitchIcon()
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
            case .fan:
                image = .fanIcon
            case .automation:
                image = .homeAutomationIcon
            case .todo:
                image = .checkboxMarkedOutlineIcon
            case .climate:
                image = .homeThermometerOutlineIcon
            }
        }

        return image
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

    private func parseRGBColor(from value: Any?) -> [Int]? {
        if let rgb = value as? [Int] {
            return rgb
        }
        if let rgbAny = value as? [Any] {
            let ints = rgbAny.compactMap { $0 as? Int }
            return ints.count == 3 ? ints : nil
        }
        return nil
    }

    private func parseHSColor(from value: Any?) -> [Double]? {
        if let hs = value as? [Double] {
            return hs
        }
        if let hsAny = value as? [Any] {
            let doubles = hsAny.compactMap { value -> Double? in
                if let double = value as? Double {
                    return double
                }
                if let number = value as? NSNumber {
                    return number.doubleValue
                }
                if let string = value as? String {
                    return Double(string)
                }
                return nil
            }
            return doubles.count >= 2 ? Array(doubles.prefix(2)) : nil
        }
        return nil
    }
}
