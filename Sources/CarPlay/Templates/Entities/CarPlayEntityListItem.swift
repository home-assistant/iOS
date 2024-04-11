import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayEntityListItem: CarPlayListItemProvider {
    var entity: HAEntity
    var template: CPListItem
    weak var interfaceController: CPInterfaceController?

    init(entity: HAEntity) {
        self.template = CPListItem(text: nil, detailText: nil)
        self.entity = entity
        update(entity: entity)
    }

    func update(entity: HAEntity) {
        self.entity = entity
        template.setText(entity.attributes.friendlyName ?? entity.entityId)
        template.setDetailText(entity.localizedState)
        template
            .setImage(
                entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon
                    .carPlayIcon()
            )
    }
}
