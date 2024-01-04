import Foundation
import HAKit
import PromiseKit
import SwiftUI
import UIKit

public extension HAEntity {

    func onPress(for api: HomeAssistantAPI) -> Promise<Void> {
        let domain = domain
        var service: String
        switch domain {
        case "lock":
            service = state == "unlocked" ? "lock" : "unlock"
        case "cover":
            service = state == "open" ? "close_cover" : "open_cover"
        case "button", "input_button":
            service = "press"
        case "scene":
            service = "turn_on"
        default:
            service = state == "on" ? "turn_off" : "turn_on"
        }
        return api.CallService(domain: domain, service: service, serviceData: ["entity_id": entityId])
    }

    func getIcon(size: CGSize = CGSize(width: 64, height: 64)) -> UIImage? {
        var image = MaterialDesignIcons.bookmarkIcon
        var tint: UIColor = .white

        if let icon = attributes.icon?.normalizingIconString {
            image = MaterialDesignIcons(named: icon)
        } else {
            let compareState = state
            switch domain {
            case "button":
                guard let deviceClass = attributes.dictionary["device_class"] as? String else { break }
                if deviceClass == "restart" {
                    image = MaterialDesignIcons.restartIcon
                } else if deviceClass == "update" {
                    image = MaterialDesignIcons.packageUpIcon
                } else {
                    image = MaterialDesignIcons.gestureTapButtonIcon
                }
            case "cover":
                image = getCoverIcon()
            case "input_boolean":
                if !entityId.hasSuffix(".ha_ios_placeholder") {
                    if compareState == "on" {
                        image = MaterialDesignIcons.checkCircleOutlineIcon
                    } else {
                        image = MaterialDesignIcons.closeCircleOutlineIcon
                    }
                } else {
                    image = MaterialDesignIcons.toggleSwitchOutlineIcon
                }
            case "input_button":
                image = MaterialDesignIcons.gestureTapButtonIcon
            case "light":
                image = MaterialDesignIcons.lightbulbIcon
            case "lock":
                switch compareState {
                case "unlocked":
                    image = MaterialDesignIcons.lockOpenIcon
                case "jammed":
                    image = MaterialDesignIcons.lockAlertIcon
                case "locking", "unlocking":
                    image = MaterialDesignIcons.lockClockIcon
                default:
                    image = MaterialDesignIcons.lockIcon
                }
            case "person":
                image = MaterialDesignIcons.accountIcon
            case "scene":
                image = MaterialDesignIcons.paletteOutlineIcon
            case "script":
                image = MaterialDesignIcons.scriptTextOutlineIcon
            case "sensor":
                image = MaterialDesignIcons.eyeIcon
            case "switch":
                if !entityId.hasSuffix(".ha_ios_placeholder") {
                    let deviceClass = attributes.dictionary["device_class"] as? String
                    switch deviceClass {
                    case "outlet":
                        image = compareState == "on" ? MaterialDesignIcons.powerPlugIcon : MaterialDesignIcons
                            .powerPlugOffIcon
                    case "switch":
                        image = compareState == "on" ? MaterialDesignIcons.toggleSwitchIcon : MaterialDesignIcons
                            .toggleSwitchOffIcon
                    default:
                        image = MaterialDesignIcons.flashIcon
                    }
                } else {
                    image = MaterialDesignIcons.lightSwitchIcon
                }
            case "zone":
                image = MaterialDesignIcons.mapMarkerRadiusIcon
            default:
                image = MaterialDesignIcons.bookmarkIcon
            }
        }

        // TODO: Improve logic and create enum for states
        if state == "on" {
            tint = .yellow
        }

        return image.image(ofSize: size, color: tint)
    }

    private func getCoverIcon() -> MaterialDesignIcons {
        let device_class = attributes.dictionary["device_class"] as? String
        let state = state
        let open = state != "closed"

        switch device_class {
        case "garage":
            switch state {
            case "opening": return MaterialDesignIcons.arrowUpBoxIcon
            case "closing": return MaterialDesignIcons.arrowDownBoxIcon
            case "closed": return MaterialDesignIcons.garageIcon
            default: return MaterialDesignIcons.garageOpenIcon
            }
        case "gate":
            switch state {
            case "opening", "closing": return MaterialDesignIcons.gateArrowRightIcon
            case "closed": return MaterialDesignIcons.gateIcon
            default: return MaterialDesignIcons.gateOpenIcon
            }
        case "door":
            return open ? MaterialDesignIcons.doorOpenIcon : MaterialDesignIcons.doorClosedIcon
        case "damper":
            return open ? MaterialDesignIcons.circleIcon : MaterialDesignIcons.circleSlice8Icon
        case "shutter":
            switch state {
            case "opening": return MaterialDesignIcons.arrowUpBoxIcon
            case "closing": return MaterialDesignIcons.arrowDownBoxIcon
            case "closed": return MaterialDesignIcons.windowShutterIcon
            default: return MaterialDesignIcons.windowShutterOpenIcon
            }
        case "curtain":
            switch state {
            case "opening": return MaterialDesignIcons.arrowSplitVerticalIcon
            case "closing": return MaterialDesignIcons.arrowCollapseHorizontalIcon
            case "closed": return MaterialDesignIcons.curtainsClosedIcon
            default: return MaterialDesignIcons.curtainsIcon
            }
        case "blind", "shade":
            switch state {
            case "opening": return MaterialDesignIcons.arrowUpBoxIcon
            case "closing": return MaterialDesignIcons.arrowDownBoxIcon
            case "closed": return MaterialDesignIcons.blindsIcon
            default: return MaterialDesignIcons.blindsOpenIcon
            }
        default:
            switch state {
            case "opening": return MaterialDesignIcons.arrowUpBoxIcon
            case "closing": return MaterialDesignIcons.arrowDownBoxIcon
            case "closed": return MaterialDesignIcons.windowClosedIcon
            default: return MaterialDesignIcons.windowOpenIcon
            }
        }
    }

    var localizedState: String {
        CoreStrings.getDomainStateLocalizedTitle(state: state) ?? FrontendStrings.getDefaultStateLocalizedTitle(state: state) ?? state
    }
}
