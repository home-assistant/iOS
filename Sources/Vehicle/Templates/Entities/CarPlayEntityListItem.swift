import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayEntityListItem: CarPlayListItemProvider {
    var entity: HAEntity
    var template: CPListItem
    weak var interfaceController: CPInterfaceController?

    private var userInterfaceStyle: UIUserInterfaceStyle? {
        interfaceController?.carTraitCollection.userInterfaceStyle
    }

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
                entity.getIcon(carUserInterfaceStyle: userInterfaceStyle) ?? MaterialDesignIcons.bookmarkIcon
                    .carPlayIcon(carUserInterfaceStyle: userInterfaceStyle)
            )
    }
}
