import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayEntityListItem: CarPlayListItemProvider {
    var serverId: String
    var entity: HAEntity
    var template: CPListItem
    weak var interfaceController: CPInterfaceController?

    init(serverId: String, entity: HAEntity) {
        self.template = CPListItem(text: nil, detailText: nil)
        self.entity = entity
        self.serverId = serverId
        update(serverId: serverId, entity: entity)
    }

    func update(serverId: String, entity: HAEntity) {
        self.entity = entity
        self.serverId = serverId
        template.setText(entity.attributes.friendlyName ?? entity.entityId)
        template.setDetailText(entity.localizedState)
        template
            .setImage(
                entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon
                    .carPlayIcon()
            )
    }
}
