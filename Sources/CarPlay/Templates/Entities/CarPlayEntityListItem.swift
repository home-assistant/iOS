import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayEntityListItem: CarPlayListItemProvider {
    var serverId: String
    var entity: HAEntity
    let magicItem: MagicItem?
    let magicItemInfo: MagicItem.Info?
    var template: CPListItem
    weak var interfaceController: CPInterfaceController?
    var area: String?

    private static let detailTextSeparator = " • "

    /// Whether the entity has a dynamic icon that changes based on state
    private var entityHasDynamicIcon: Bool {
        guard let entityDomain = Domain(entityId: entity.entityId) else { return false }
        return [.cover, .inputBoolean, .light, .lock, .switch].contains(entityDomain)
    }

    /// Whether the entity has a state that doesnt bring value to the user when accessing from the car
    private var entityHasIrrelevantState: Bool {
        guard let entityDomain = Domain(entityId: entity.entityId) else { return false }
        return [.script, .scene].contains(entityDomain)
    }

    init(
        serverId: String,
        entity: HAEntity,
        magicItem: MagicItem? = nil,
        magicItemInfo: MagicItem.Info? = nil,
        area: String? = nil
    ) {
        self.template = CPListItem(text: nil, detailText: nil)
        self.entity = entity
        self.serverId = serverId
        self.magicItem = magicItem
        self.magicItemInfo = magicItemInfo
        self.area = area
        update(serverId: serverId, entity: entity)
    }

    func update(serverId: String, entity: HAEntity) {
        self.entity = entity
        self.serverId = serverId

        var displayText = entity.attributes.friendlyName ?? entity.entityId
        var image = entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon.carPlayIcon()

        if let magicItem, let magicItemInfo {
            displayText = magicItem.name(info: magicItemInfo)

            // Check if user has customized the icon color
            let customIconColor: UIColor? = {
                if let iconColorString = magicItem.customization?.iconColor {
                    return UIColor(hex: iconColorString)
                }
                return nil
            }()

            if !entityHasDynamicIcon {
                // Non-dynamic icons: use custom icon with custom color
                image = magicItem.icon(info: magicItemInfo).carPlayIcon(color: customIconColor)
            } else {
                // Dynamic icons: use state-based icon with smart coloring
                let iconColor = determineIconColor(
                    entityState: entity.state,
                    customColor: customIconColor
                )
                image = entity.getIconWithoutColor().carPlayIcon(color: iconColor)
            }
        }

        template.setText(displayText)
        if !entityHasIrrelevantState {
            var detailsText = ""
            if let area {
                detailsText = area + Self.detailTextSeparator
            }
            detailsText += getContextualStateDescription()
            template.setDetailText(detailsText)
        }
        template.setImage(image)
    }

    /// Returns a context-aware state description based on entity domain and device class
    private func getContextualStateDescription() -> String {
        let baseState = entity.localizedState.leadingCapitalized

        // Add unit of measurement if available
        if let unitOfMeasurement = entity.attributes.dictionary["unit_of_measurement"] {
            return "\(baseState) \(unitOfMeasurement)"
        }

        // Get device class for more specific state descriptions
        guard let domain = Domain(entityId: entity.entityId),
              let state = Domain.State(rawValue: entity.state) else {
            return baseState
        }

        let deviceClass = entity.deviceClass

        // Provide context-aware descriptions for binary sensors with device classes
        if domain == .binarySensor {
            switch deviceClass {
            case .door:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentDoorStateOn :
                    CoreStrings.componentBinarySensorEntityComponentDoorStateOff
            case .window:
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentWindowStateOn :
                    CoreStrings.componentBinarySensorEntityComponentWindowStateOff
            case .garage:
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
            default:
                // For other device classes without specific strings, use generic on/off
                return state == .on ?
                    CoreStrings.componentBinarySensorEntityComponentStateOn :
                    CoreStrings.componentBinarySensorEntityComponentStateOff
            }
        }

        // Provide context-aware descriptions for covers with device classes
        if domain == .cover {
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
        if domain == .lock {
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

    /// Determines the icon color based on entity state and custom color preference
    /// - Parameters:
    ///   - entityState: The current state of the entity
    ///   - customColor: Optional custom color set by the user
    /// - Returns: The color to use for the icon
    private func determineIconColor(entityState: String, customColor: UIColor?) -> UIColor? {
        guard let state = Domain.State(rawValue: entityState) else {
            // Unknown state: use custom color if available, otherwise light gray
            return customColor ?? .lightGray
        }

        // Inactive states get neutral gray color regardless of custom color
        let inactiveStates: [Domain.State] = [.locked, .off, .closed, .locking, .closing]
        if inactiveStates.contains(state) {
            return .lightGray
        }

        // Active states use custom color if available, otherwise default accent color
        let activeStates: [Domain.State] = [.unlocked, .on, .open, .unlocking, .opening]
        if activeStates.contains(state) {
            return customColor ?? AppConstants.lighterTintColor
        }

        // Unavailable/unknown states get gray
        if [.unavailable, .unknown].contains(state) {
            return .gray
        }

        // Jammed state gets a warning color
        if state == .jammed {
            return .systemOrange
        }

        // Default fallback
        return customColor ?? .lightGray
    }
}
