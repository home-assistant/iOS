import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayEntityListItem: CarPlayListItemProvider {
    private struct DisplayContent {
        let text: String
        let detailText: String?
        let image: UIImage
    }

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

        let content = displayContent()
        template.setText(content.text)
        template.setDetailText(content.detailText)
        template.setImage(content.image)
    }

    @available(iOS 26.0, *)
    func condensedElement(accessorySymbolName: String? = nil) -> CPListImageRowItemCondensedElement {
        let content = displayContent()
        return CPListImageRowItemCondensedElement(
            image: content.image.scaledToSize(CPListImageRowItemCondensedElement.maximumImageSize),
            imageShape: .circular,
            title: content.text,
            subtitle: content.detailText,
            accessorySymbolName: accessorySymbolName
        )
    }

    private func displayContent() -> DisplayContent {
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

            let userHasCustomizedIcon = magicItem.customization?.iconIsCustomized == true
            if !entityHasDynamicIcon || userHasCustomizedIcon {
                // Use the configured icon, respecting any explicit user customization
                image = magicItem.icon(info: magicItemInfo).carPlayIcon(color: customIconColor)
            } else {
                // Dynamic entity icons should reflect the live server-provided color,
                // matching the main entities/controls views instead of saved quick-access tint.
                let iconColor = entity.carPlayIconColor()
                image = entity.getMDI().carPlayIcon(color: iconColor)
            }
        }

        var detailText: String?
        if !entityHasIrrelevantState {
            var renderedDetailText = getContextualStateDescription()
            if let area, !renderedDetailText.isEmpty {
                renderedDetailText += Self.detailTextSeparator + area
            }
            detailText = renderedDetailText
        }

        return DisplayContent(
            text: displayText,
            detailText: detailText,
            image: image
        )
    }

    /// Returns a context-aware state description based on entity domain and device class
    private func getContextualStateDescription() -> String {
        if let domain = Domain(entityId: entity.entityId) {
            return domain.contextualStateDescription(for: entity)
        }

        let baseState = entity.localizedState.leadingCapitalized

        // Add unit of measurement if available
        if let unitOfMeasurement = entity.attributes.dictionary["unit_of_measurement"] {
            return "\(baseState) \(unitOfMeasurement)"
        }

        return baseState
    }
}
