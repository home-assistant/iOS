import CarPlay
import Foundation
import HAKit
import PromiseKit
import RealmSwift
import Shared

@available(iOS 16.0, *)
final class CarPlayQuickAccessTemplate: CarPlayTemplateProvider {
    private struct RowDisplayItem {
        let magicItem: MagicItem
        let info: MagicItem.Info
        let image: UIImage
        let title: String
        let subtitle: String?
        let currentState: String
    }

    private let viewModel: CarPlayQuickAccessViewModel

    private let paginatedList = CarPlayPaginatedListTemplate(
        title: L10n.CarPlay.Navigation.Tab.quickAccess,
        items: [],
        paginationStyle: .inline
    )
    private let quickAccessItemsPerRow = 6
    var template: CPListTemplate

    private var magicItemProvider: MagicItemProviderProtocol = Current.magicItemProvider()
    weak var interfaceController: CPInterfaceController?
    private var entityProviders: [CarPlayEntityListItem] = []
    private var currentItems: [MagicItem] = []
    private var currentLayout: CarPlayQuickAccessLayout = .grid
    private var entitiesPerServer: [String: HACachedStates] = [:]

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    private lazy var introduceQuickAccessListItem: CPListItem = {
        let item = CPListItem(
            text: L10n.CarPlay.QuickAccess.Intro.Item.title,
            detailText: L10n.CarPlay.Action.Intro.Item.body,
            image: MaterialDesignIcons.homeLightningBoltIcon
                .carPlayIcon()
        )
        item.handler = { [weak self] _, completion in
            self?.viewModel.sendIntroNotification()
            self?.displayItemResultIcon(on: item, success: true)
            completion()
        }
        return item
    }()

    init(viewModel: CarPlayQuickAccessViewModel) {
        self.viewModel = viewModel

        guard let template = paginatedList.listTemplate else {
            fatalError("Expected CarPlayPaginatedListTemplate to create a CPListTemplate")
        }
        self.template = template
        template.tabTitle = L10n.CarPlay.Navigation.Tab.quickAccess
        template.tabImage = MaterialDesignIcons.lightningBoltIcon.carPlayIcon()
        template.tabSystemItem = .more

        self.viewModel.templateProvider = self
        presentIntroductionItem()
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            /* no-op */
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        entitiesPerServer[serverId] = entities
        if #available(iOS 26.0, *), currentLayout == .grid, !currentItems.isEmpty {
            paginatedList.updateItems(items: rowItems(items: currentItems))
            return
        }
        entityProviders.forEach { item in
            guard serverId == item.serverId else { return }
            guard let entity = entities.all.filter({ $0.entityId == item.entity.entityId }).first else { return }
            item.update(serverId: serverId, entity: entity)
        }
    }

    func update() {
        magicItemProvider.loadInformation { [weak self] _ in
            self?.viewModel.update()
        }
    }

    func updateList(for items: [MagicItem], layout: CarPlayQuickAccessLayout) {
        currentItems = items
        currentLayout = layout
        guard !items.isEmpty else {
            presentIntroductionItem()
            return
        }
        if #available(iOS 26.0, *), layout == .grid {
            paginatedList.updateItems(items: rowItems(items: items))
        } else {
            paginatedList.updateItems(items: listItems(items: items))
        }
    }

    private func presentIntroductionItem() {
        template.trailingNavigationBarButtons = []
        template.updateSections([.init(items: [introduceQuickAccessListItem])])
    }

    private func listItems(items: [MagicItem]) -> [CPListItem] {
        entityProviders = []
        let entityToAreaMap = entityToAreaMap()

        let items: [CPListItem?] = items.compactMap { magicItem in
            let info = info(for: magicItem)
            switch magicItem.type {
            case .entity:
                guard let placeholderItem = entitiesPerServer[magicItem.serverId]?.all
                    .first(where: { $0.entityId == magicItem.id }) ?? placeholderEntity(id: magicItem.id),
                    let rowDisplayItem = rowDisplayItem(for: magicItem, entityToAreaMap: entityToAreaMap) else {
                    return .init(text: "", detailText: "")
                }
                let entityProvider = CarPlayEntityListItem(
                    serverId: magicItem.serverId,
                    entity: placeholderItem,
                    magicItem: magicItem,
                    magicItemInfo: info,
                    area: entityToAreaMap[placeholderItem.entityId]
                )
                let listItem = entityProvider.template
                listItem.handler = { [weak self] _, _ in
                    self?.itemTap(
                        magicItem: magicItem,
                        info: info,
                        currentItemState: rowDisplayItem.currentState,
                        resultHandler: { [weak self] success in
                            self?.displayItemResultIcon(on: listItem, success: success)
                        }
                    )
                }
                entityProviders.append(entityProvider)
                return listItem
            default:
                let item = CPListItem(
                    text: magicItem.name(info: info),
                    detailText: subtitle(for: magicItem),
                    image: magicItem.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor))
                )
                item.handler = { [weak self] _, _ in
                    self?.itemTap(
                        magicItem: magicItem,
                        info: info,
                        resultHandler: { [weak self] success in
                            self?.displayItemResultIcon(on: item, success: success)
                        }
                    )
                }
                return item
            }
        }

        return items.compactMap({ $0 })
    }

    @available(iOS 26.0, *)
    private func rowItems(items: [MagicItem]) -> [any CPListTemplateItem] {
        let entityToAreaMap = entityToAreaMap()
        let displayItems = items.compactMap { rowDisplayItem(for: $0, entityToAreaMap: entityToAreaMap) }

        return stride(from: 0, to: displayItems.count, by: quickAccessItemsPerRow).map { startIndex in
            let pageItems = Array(displayItems[startIndex ..< min(
                startIndex + quickAccessItemsPerRow,
                displayItems.count
            )])
            let elements = pageItems.map { item in
                CPListImageRowItemCondensedElement(
                    image: item.image.scaledToSize(CPListImageRowItemCondensedElement.maximumImageSize),
                    imageShape: .circular,
                    title: item.title,
                    subtitle: item.subtitle,
                    accessorySymbolName: nil
                )
            }

            let rowItem = CPListImageRowItem(
                text: nil,
                condensedElements: elements,
                allowsMultipleLines: true
            )
            rowItem.listImageRowHandler = { [weak self] item, index, completion in
                guard pageItems.indices.contains(index) else {
                    completion()
                    return
                }

                let selectedItem = pageItems[index]
                self?.itemTap(
                    magicItem: selectedItem.magicItem,
                    info: selectedItem.info,
                    currentItemState: selectedItem.currentState,
                    resultHandler: { [weak self] success in
                        self?.displayItemResultIcon(
                            on: item,
                            elementIndex: index,
                            originalImage: selectedItem.image
                                .scaledToSize(CPListImageRowItemCondensedElement.maximumImageSize),
                            success: success
                        )
                    }
                )
                completion()
            }
            return rowItem
        }
    }

    private func placeholderEntity(id: String) -> HAEntity? {
        try? HAEntity(
            entityId: id,
            state: "",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    private func itemTap(
        magicItem: MagicItem,
        info: MagicItem.Info,
        currentItemState: String = "",
        resultHandler: @escaping (Bool) -> Void
    ) {
        // Check if this is a lock entity - locks always require confirmation
        let isLockEntity = magicItem
            .type == .entity && Domain(entityId: magicItem.id) == .lock

        if isLockEntity {
            // For lock entities, show lock-specific confirmation
            showLockConfirmation(magicItem: magicItem, info: info, currentState: currentItemState) { [weak self] in
                self?.executeLockEntity(magicItem, currentState: currentItemState, resultHandler: resultHandler)
            }
        } else if info.customization?.requiresConfirmation ?? false {
            showConfirmationForRunningMagicItem(item: magicItem, info: info) { [weak self] in
                self?.executeMagicItem(magicItem, resultHandler: resultHandler)
            }
        } else {
            executeMagicItem(magicItem, resultHandler: resultHandler)
        }
    }

    private func executeMagicItem(
        _ magicItem: MagicItem,
        resultHandler: @escaping (Bool) -> Void
    ) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }) else {
            Current.Log.error("Failed to get server for magic item id: \(magicItem.id)")
            resultHandler(false)
            return
        }
        magicItem.execute(on: server, source: .CarPlay) { success in
            resultHandler(success)
        }
    }

    /// Execute a lock entity using the shared CarPlayLockConfirmation.execute method
    private func executeLockEntity(
        _ magicItem: MagicItem,
        currentState: String,
        resultHandler: @escaping (Bool) -> Void
    ) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }) else {
            Current.Log.error("Failed to get server for lock magic item id: \(magicItem.id)")
            resultHandler(false)
            return
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to execute lock entity")
            resultHandler(false)
            return
        }

        // Use shared execution method for consistency across all CarPlay templates
        CarPlayLockConfirmation.execute(
            entityId: magicItem.id,
            currentState: currentState,
            api: api
        ) { success in
            resultHandler(success)
        }
    }

    private func showConfirmationForRunningMagicItem(
        item: MagicItem,
        info: MagicItem.Info,
        completion: @escaping () -> Void
    ) {
        let alert = CPAlertTemplate(titleVariants: [
            L10n.Watch.Home.Run.Confirmation.title(item.name(info: info)),
        ], actions: [
            .init(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
            .init(title: L10n.Alerts.Confirm.confirm, style: .default, handler: { [weak self] _ in
                completion()
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
        ])

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }

    private func showLockConfirmation(
        magicItem: MagicItem,
        info: MagicItem.Info,
        currentState: String,
        completion: @escaping () -> Void
    ) {
        CarPlayLockConfirmation.show(
            entityName: info.name,
            currentState: currentState,
            interfaceController: interfaceController,
            completion: completion
        )
    }

    // Present a checkmark or cross depending on success or failure
    // After 2 seconds the original icon is restored
    private func displayItemResultIcon(on item: CPListItem, success: Bool) {
        let itemOriginalIcon = item.image
        if success {
            item.setImage(MaterialDesignIcons.checkIcon.carPlayIcon(color: AppConstants.tintColor))
        } else {
            item.setImage(MaterialDesignIcons.closeIcon.carPlayIcon(color: .red))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            item.setImage(itemOriginalIcon)
        }
    }

    @available(iOS 26.0, *)
    private func displayItemResultIcon(
        on item: CPListImageRowItem,
        elementIndex: Int,
        originalImage: UIImage,
        success: Bool
    ) {
        guard item.elements.indices.contains(elementIndex) else { return }

        let updatedElements = item.elements
        updatedElements[elementIndex].image = success
            ? MaterialDesignIcons.checkIcon.image(
                ofSize: CPListImageRowItemCondensedElement.maximumImageSize,
                color: AppConstants.tintColor
            )
            : MaterialDesignIcons.closeIcon.image(
                ofSize: CPListImageRowItemCondensedElement.maximumImageSize,
                color: .red
            )
        item.elements = updatedElements

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard item.elements.indices.contains(elementIndex) else { return }
            let restoredElements = item.elements
            restoredElements[elementIndex].image = originalImage
            item.elements = restoredElements
        }
    }

    private func info(for magicItem: MagicItem) -> MagicItem.Info {
        magicItemProvider.getInfo(for: magicItem) ?? .init(
            id: magicItem.id,
            name: magicItem.id,
            iconName: "",
            customization: nil
        )
    }

    private func subtitle(for magicItem: MagicItem) -> String? {
        Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId })?.info.name
    }

    private func rowDisplayItem(
        for magicItem: MagicItem,
        entityToAreaMap: [String: String]
    ) -> RowDisplayItem? {
        let info = info(for: magicItem)

        switch magicItem.type {
        case .entity:
            guard let placeholderItem = entitiesPerServer[magicItem.serverId]?.all
                .first(where: { $0.entityId == magicItem.id }) ?? placeholderEntity(id: magicItem.id) else {
                Current.Log.error("Failed to create placeholder entity for magic item id: \(magicItem.id)")
                return nil
            }

            let area = entityToAreaMap[placeholderItem.entityId]
            let entityProvider = CarPlayEntityListItem(
                serverId: magicItem.serverId,
                entity: placeholderItem,
                magicItem: magicItem,
                magicItemInfo: info,
                area: area
            )
            if #available(iOS 26.0, *) {
                let condensedElement = entityProvider.condensedElement()
                return RowDisplayItem(
                    magicItem: magicItem,
                    info: info,
                    image: condensedElement.image,
                    title: condensedElement.title,
                    subtitle: condensedElement.subtitle,
                    currentState: entityProvider.entity.state
                )
            } else {
                return RowDisplayItem(
                    magicItem: magicItem,
                    info: info,
                    image: entityProvider.template.image ?? MaterialDesignIcons.bookmarkIcon.carPlayIcon(),
                    title: entityProvider.template.text ?? info.name,
                    subtitle: entityProvider.template.detailText,
                    currentState: entityProvider.entity.state
                )
            }
        default:
            return RowDisplayItem(
                magicItem: magicItem,
                info: info,
                image: magicItem.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor)),
                title: magicItem.name(info: info),
                subtitle: subtitle(for: magicItem),
                currentState: ""
            )
        }
    }

    private func entityToAreaMap() -> [String: String] {
        var entityToAreaMap: [String: String] = [:]
        for server in Current.servers.all {
            let areas: [AppArea]
            do {
                areas = try AppArea.fetchAreas(for: server.identifier.rawValue)
            } catch {
                Current.Log.error("Failed to fetch areas for CarPlay quick access: \(error.localizedDescription)")
                areas = []
            }
            for area in areas {
                for entityId in area.entities {
                    entityToAreaMap[entityId] = area.name
                }
            }
        }
        return entityToAreaMap
    }
}
