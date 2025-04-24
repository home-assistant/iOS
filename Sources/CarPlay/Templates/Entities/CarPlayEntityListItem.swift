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

    /// Whether the entity has a dynamic icon that changes based on state
    private var entityHasDynamicIcon: Bool {
        guard let entityDomain = Domain(entityId: entity.entityId) else { return false }
        return [.cover, .inputBoolean, .light, .switch].contains(entityDomain)
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
        magicItemInfo: MagicItem.Info? = nil
    ) {
        self.template = CPListItem(text: nil, detailText: nil)
        self.entity = entity
        self.serverId = serverId
        self.magicItem = magicItem
        self.magicItemInfo = magicItemInfo
        update(serverId: serverId, entity: entity)
    }

    func update(serverId: String, entity: HAEntity) {
        self.entity = entity
        self.serverId = serverId

        var displayText = entity.attributes.friendlyName ?? entity.entityId
        var image = entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon.carPlayIcon()
        if let magicItem, let magicItemInfo {
            displayText = magicItem.name(info: magicItemInfo)

            if !entityHasDynamicIcon {
                var iconColor: UIColor?
                if let iconColorString = magicItem.customization?.iconColor {
                    iconColor = UIColor(hex: iconColorString)
                }
                image = magicItem.icon(info: magicItemInfo).carPlayIcon(color: iconColor)
            }
        }
        template.setText(displayText)
        if !entityHasIrrelevantState {
            template.setDetailText(entity.localizedState.leadingCapitalized)
        }
        template.setImage(image)
    }
}
