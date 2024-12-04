import Foundation
import HAKit
import PromiseKit
import Shared
import SwiftUI
import UIKit

extension HAEntity {
    enum DeviceClass: String {
        case garage
        case gate
        case door
        case damper
        case shutter
        case curtain
        case blind
        case shade
        case restart
        case update
        case outlet
        case `switch`
        case unknown
    }

    var deviceClass: DeviceClass {
        guard let deviceClassString = attributes.dictionary["device_class"] as? String,
              let deviceClass = DeviceClass(rawValue: deviceClassString) else {
            return .unknown
        }

        return deviceClass
    }

    func onPress(for api: HomeAssistantAPI) -> Promise<Void> {
        var request: HATypedRequest<HAResponseVoid>?
        switch Domain(rawValue: domain) {
        case .button:
            request = .pressButton(domain: .button, entityId: entityId)
        case .cover:
            request = .toggleDomain(domain: .cover, entityId: entityId)
        case .inputBoolean:
            request = .toggleDomain(domain: .inputBoolean, entityId: entityId)
        case .inputButton:
            request = .pressButton(domain: .inputButton, entityId: entityId)
        case .light:
            request = .toggleDomain(domain: .light, entityId: entityId)
        case .scene:
            request = .applyScene(entityId: entityId)
        case .script:
            request = .runScript(entityId: entityId)
        case .switch:
            request = .toggleDomain(domain: .switch, entityId: entityId)
        case .lock:
            guard let state = Domain.State(rawValue: state) else { return .value }
            switch state {
            case .unlocking, .unlocked, .opening:
                request = .lockLock(entityId: entityId)
            case .locked, .locking:
                request = .unlockLock(entityId: entityId)
            default:
                break
            }
        case .none, .sensor, .binarySensor, .zone, .person:
            break
        }
        if let request {
            return api.connection.send(request).promise
                .map { _ in () }
        } else {
            return .value
        }
    }

    func getIcon() -> UIImage? {
        var image = MaterialDesignIcons.bookmarkIcon
        var tint: UIColor?

        if let icon = attributes.icon?.normalizingIconString {
            image = MaterialDesignIcons(named: icon)
        } else {
            guard let domain = Domain(rawValue: domain) else { return nil }
            switch domain {
            case .button:
                image = getButtonIcon()
            case .cover:
                image = getCoverIcon()
            case .inputBoolean:
                image = getInputBooleanIcon()
            case .inputButton:
                image = MaterialDesignIcons.gestureTapButtonIcon
            case .light:
                image = MaterialDesignIcons.lightbulbIcon
            case .lock:
                image = getLockIcon()
            case .scene:
                image = MaterialDesignIcons.paletteOutlineIcon
            case .script:
                image = MaterialDesignIcons.scriptTextOutlineIcon
            case .switch:
                image = getSwitchIcon()
            case .sensor:
                image = MaterialDesignIcons.eyeIcon
            case .binarySensor:
                image = MaterialDesignIcons.eyeIcon
            case .zone:
                image = MaterialDesignIcons.mapIcon
            case .person:
                image = MaterialDesignIcons.accountIcon
            }
        }

        if let state = Domain.State(rawValue: state) {
            if [.on, .open, .opening, .unlocked, .unlocking].contains(state) {
                tint = AppConstants.lighterTintColor
            } else if [.unavailable, .unknown].contains(state) {
                tint = .gray
            } else {
                tint = .lightGray
            }
        }

        return image.carPlayIcon(color: tint)
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
        let state = state

        guard let state = Domain.State(rawValue: state) else { return MaterialDesignIcons.bookmarkIcon }

        switch deviceClass {
        case .garage:
            switch state {
            case .opening: return MaterialDesignIcons.arrowUpBoxIcon
            case .closing: return MaterialDesignIcons.arrowDownBoxIcon
            case .closed: return MaterialDesignIcons.garageIcon
            default: return MaterialDesignIcons.garageOpenIcon
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
