import CarPlay
import Foundation
import HAKit
import PromiseKit
import RealmSwift
import Shared

@available(iOS 16.0, *)
final class CarPlayQuickAccessTemplate: CarPlayTemplateProvider {
    private static let minimumExecutingDuration: TimeInterval = 1.5

    private struct RowDisplayItem {
        let magicItem: MagicItem
        let info: MagicItem.Info
        let image: UIImage
        let iconColor: UIColor?
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
    var template: CPListTemplate

    private var magicItemProvider: MagicItemProviderProtocol = Current.magicItemProvider()
    weak var interfaceController: CPInterfaceController?
    private var entityProviders: [CarPlayEntityListItem] = []
    private var currentItems: [MagicItem] = []
    private var currentLayout: CarPlayQuickAccessLayout = .grid
    private var entitiesPerServer: [String: HACachedStates] = [:]
    private var executingItemIds: Set<String> = []
    private var executingStartedAt: [String: Date] = [:]
    private var pendingExecutingClearWorkItems: [String: DispatchWorkItem] = [:]

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
        guard !currentItems.isEmpty else { return }
        refreshCurrentPresentation()
    }

    private func executionKey(for magicItem: MagicItem) -> String {
        magicItem.serverUniqueId
    }

    private func isExecuting(_ magicItem: MagicItem) -> Bool {
        executingItemIds.contains(executionKey(for: magicItem))
    }

    private func beginExecuting(_ magicItem: MagicItem) {
        let key = executionKey(for: magicItem)
        pendingExecutingClearWorkItems[key]?.cancel()
        pendingExecutingClearWorkItems[key] = nil
        executingItemIds.insert(key)
        executingStartedAt[key] = Date()
        refreshCurrentPresentation()
    }

    private func endExecuting(_ magicItem: MagicItem) {
        let key = executionKey(for: magicItem)
        guard executingItemIds.contains(key) else { return }

        pendingExecutingClearWorkItems[key]?.cancel()
        let delay = max(
            0,
            Self.minimumExecutingDuration - Date().timeIntervalSince(executingStartedAt[key] ?? Date())
        )
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            pendingExecutingClearWorkItems[key] = nil
            executingItemIds.remove(key)
            executingStartedAt[key] = nil
            refreshCurrentPresentation()
        }
        pendingExecutingClearWorkItems[key] = workItem

        if delay == 0 {
            workItem.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
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
        refreshCurrentPresentation()
    }

    private func presentIntroductionItem() {
        template.trailingNavigationBarButtons = []
        template.updateSections([.init(items: [introduceQuickAccessListItem])])
    }

    private func refreshCurrentPresentation() {
        guard !currentItems.isEmpty else { return }
        if #available(iOS 26.0, *), currentLayout == .grid {
            paginatedList.updateItems(items: rowItems(items: currentItems))
        } else {
            paginatedList.updateItems(items: listItems(items: currentItems))
        }
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
                if isExecuting(magicItem) {
                    listItem.setDetailText(CarPlayEntityListItem.executingSubtitle)
                }
                listItem.handler = { [weak self] _, _ in
                    self?.itemTap(
                        magicItem: magicItem,
                        info: info,
                        currentItemState: rowDisplayItem.currentState,
                        executionStarted: { [weak self] in self?.beginExecuting(magicItem) },
                        executionFinished: { [weak self] in self?.endExecuting(magicItem) }
                    )
                }
                entityProviders.append(entityProvider)
                return listItem
            default:
                let item = CPListItem(
                    text: magicItem.name(info: info),
                    detailText: renderedSubtitle(for: magicItem, defaultSubtitle: subtitle(for: magicItem)),
                    image: magicItem.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor))
                )
                item.handler = { [weak self] _, _ in
                    self?.itemTap(
                        magicItem: magicItem,
                        info: info,
                        executionStarted: { [weak self] in self?.beginExecuting(magicItem) },
                        executionFinished: { [weak self] in self?.endExecuting(magicItem) }
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

        return stride(from: 0, to: displayItems.count, by: CarPlayCondensedEntitiesGroup.size).map { startIndex in
            let pageItems = Array(displayItems[startIndex ..< min(
                startIndex + CarPlayCondensedEntitiesGroup.size,
                displayItems.count
            )])
            let elements = pageItems.map { item in
                CPListImageRowItemCondensedElement(
                    image: item.image.carPlayCondensedElementImage(iconColor: item.iconColor),
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
            rowItem.listImageRowHandler = { [weak self] _, index, completion in
                guard pageItems.indices.contains(index) else {
                    completion()
                    return
                }

                let selectedItem = pageItems[index]
                self?.itemTap(
                    magicItem: selectedItem.magicItem,
                    info: selectedItem.info,
                    currentItemState: selectedItem.currentState,
                    executionStarted: { [weak self] in self?.beginExecuting(selectedItem.magicItem) },
                    executionFinished: { [weak self] in self?.endExecuting(selectedItem.magicItem) }
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
        executionStarted: @escaping () -> Void,
        executionFinished: @escaping () -> Void
    ) {
        // Check if this is a lock entity - locks always require confirmation
        let isLockEntity = magicItem
            .type == .entity && Domain(entityId: magicItem.id) == .lock

        if isLockEntity {
            // For lock entities, show lock-specific confirmation
            showLockConfirmation(magicItem: magicItem, info: info, currentState: currentItemState) { [weak self] in
                executionStarted()
                self?.executeLockEntity(magicItem, currentState: currentItemState, completion: executionFinished)
            }
        } else if info.customization?.requiresConfirmation ?? false {
            showConfirmationForRunningMagicItem(item: magicItem, info: info) { [weak self] in
                executionStarted()
                self?.executeMagicItem(magicItem, completion: executionFinished)
            }
        } else {
            executionStarted()
            executeMagicItem(magicItem, completion: executionFinished)
        }
    }

    private func executeMagicItem(
        _ magicItem: MagicItem,
        completion: @escaping () -> Void
    ) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }) else {
            Current.Log.error("Failed to get server for magic item id: \(magicItem.id)")
            completion()
            return
        }
        magicItem.execute(on: server, source: .CarPlay) { success in
            if !success {
                Current.Log.error("Failed executing quick access magic item id: \(magicItem.id)")
            }
            completion()
        }
    }

    /// Execute a lock entity using the shared CarPlayLockConfirmation.execute method
    private func executeLockEntity(
        _ magicItem: MagicItem,
        currentState: String,
        completion: @escaping () -> Void
    ) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }) else {
            Current.Log.error("Failed to get server for lock magic item id: \(magicItem.id)")
            completion()
            return
        }

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to execute lock entity")
            completion()
            return
        }

        // Use shared execution method for consistency across all CarPlay templates
        CarPlayLockConfirmation.execute(
            entityId: magicItem.id,
            currentState: currentState,
            api: api
        ) { success in
            if !success {
                Current.Log.error("Failed executing quick access lock entity id: \(magicItem.id)")
            }
            completion()
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

    private func renderedSubtitle(for magicItem: MagicItem, defaultSubtitle: String?) -> String? {
        isExecuting(magicItem) ? CarPlayEntityListItem.executingSubtitle : defaultSubtitle
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
            let content = entityProvider.currentDisplayContent()
            return RowDisplayItem(
                magicItem: magicItem,
                info: info,
                image: content.image,
                iconColor: content.iconColor,
                title: content.title,
                subtitle: renderedSubtitle(for: magicItem, defaultSubtitle: content.subtitle),
                currentState: entityProvider.entity.state
            )
        default:
            let iconColor = UIColor(hex: info.customization?.iconColor) ?? .haPrimary
            return RowDisplayItem(
                magicItem: magicItem,
                info: info,
                image: magicItem.icon(info: info).carPlayIcon(color: iconColor),
                iconColor: iconColor,
                title: magicItem.name(info: info),
                subtitle: renderedSubtitle(for: magicItem, defaultSubtitle: subtitle(for: magicItem)),
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
