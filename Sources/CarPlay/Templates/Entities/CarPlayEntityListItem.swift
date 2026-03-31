import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayEntityListItem: CarPlayListItemProvider {
    static let executingSubtitle = L10n.CarPlay.Action.Execute.inProgress
    private static let minimumExecutingDuration: TimeInterval = 1.5

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
    var onDeferredPresentationUpdate: (() -> Void)?
    private var temporaryDetailText: String?
    private var executingStartedAt: Date?
    private var pendingExecutingClearWorkItem: DispatchWorkItem?

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

        // Keep the temporary executing subtitle visible long enough even if the server
        // state updates immediately after the action is triggered.
        if temporaryDetailText == Self.executingSubtitle {
            scheduleExecutingClearIfNeeded()
        }

        refreshTemplate()
    }

    func setExecutingState(_ isExecuting: Bool) {
        if isExecuting {
            pendingExecutingClearWorkItem?.cancel()
            pendingExecutingClearWorkItem = nil
            executingStartedAt = Date()
            temporaryDetailText = Self.executingSubtitle
            refreshTemplate()
        } else {
            scheduleExecutingClearIfNeeded()
        }
    }

    private func scheduleExecutingClearIfNeeded() {
        guard temporaryDetailText == Self.executingSubtitle else { return }
        guard let executingStartedAt else {
            temporaryDetailText = nil
            refreshTemplate()
            return
        }

        pendingExecutingClearWorkItem?.cancel()
        let delay = max(0, Self.minimumExecutingDuration - Date().timeIntervalSince(executingStartedAt))
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            pendingExecutingClearWorkItem = nil
            self.executingStartedAt = nil
            temporaryDetailText = nil
            refreshTemplate()
            onDeferredPresentationUpdate?()
        }
        pendingExecutingClearWorkItem = workItem

        if delay == 0 {
            workItem.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func refreshTemplate() {
        let content = displayContent()
        template.setText(content.text)
        template.setDetailText(content.detailText)
        template.setImage(content.image)
    }

    @available(iOS 26.0, *)
    func condensedElement(accessorySymbolName: String? = nil) -> CPListImageRowItemCondensedElement {
        let content = displayContent()
        return CPListImageRowItemCondensedElement(
            image: content.image.carPlayCondensedElementImage(),
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

        if let temporaryDetailText {
            detailText = temporaryDetailText
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
