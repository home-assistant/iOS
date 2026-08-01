import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

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

    private struct CondensedDisplayItem {
        let image: UIImage
        let iconColor: UIColor?
        let title: String
        let subtitle: String?
        /// SF Symbol shown as trailing accessory; folders use a chevron to signal navigation.
        let accessorySymbolName: String?
        let handler: (@escaping () -> Void) -> Void
    }

    private let viewModel: CarPlayQuickAccessViewModel

    private let paginatedList: CarPlayPaginatedListTemplate
    var template: CPListTemplate

    private var magicItemProvider: MagicItemProviderProtocol = Current.magicItemProvider()
    weak var interfaceController: CPInterfaceController?
    private var listItemsByKey: [String: CPListItem] = [:]
    /// Row caches for folder content lists pushed from the Quick Access list, keyed by folder id.
    /// Rows are reused in place — same reasoning as `listItemsByKey`.
    private var folderListItemsByKey: [String: [String: CPListItem]] = [:]
    /// Add/Edit footer rows of pushed folder lists, keyed by folder id. Cached so refreshes keep
    /// the same row instances and skip `updateSections` (which resets rotary focus).
    private var folderFooterRows: [String: [CPListItem]] = [:]
    /// Folder content lists currently pushed from the Quick Access list, refreshed on state changes.
    private var openFolderTemplates: [(folderId: String, template: CPListTemplate)] = []
    private var currentItems: [MagicItem] = []
    private var currentLayout: CarPlayQuickAccessLayout = .grid
    private var currentShowAddEditButtons = true
    private var entitiesPerServer: [String: HACachedStates] = [:]
    private var lastKnownEntities: [String: HAEntity] = [:]
    private var executingItemIds: Set<String> = []
    private var executingStartedAt: [String: Date] = [:]
    private var pendingExecutingClearWorkItems: [String: DispatchWorkItem] = [:]
    private var activeAssistSession: AnyObject?
    private var addItemFlow: CarPlayAddItemFlow?
    private var editItemFlow: CarPlayEditItemFlow?
    /// Control screen pushed for domains that have one (climate); fed with the per-server state
    /// events this template receives and cleared when the list reappears (i.e. it was popped).
    private var climateControlTemplate: CarPlayClimateControlTemplate?

    /// `folder` is provided when this template renders a folder promoted to its own tab
    /// (`CarPlayQuickAccessViewModel.Source.folder`); it supplies the tab's title and icon.
    init(viewModel: CarPlayQuickAccessViewModel, folder: MagicItem? = nil) {
        self.viewModel = viewModel

        let title: String
        let tabImage: UIImage
        if let folder {
            title = folder.displayText ?? L10n.Watch.Configuration.Folder.defaultName
            tabImage = MaterialDesignIcons(
                named: folder.customization?.icon ?? MaterialDesignIcons.folderIcon.name,
                fallback: .folderIcon
            ).carPlayIcon()
        } else {
            title = L10n.CarPlay.Navigation.Tab.quickAccess
            tabImage = MaterialDesignIcons.lightningBoltIcon.carPlayIcon()
        }

        self.paginatedList = CarPlayPaginatedListTemplate(
            title: title,
            items: [],
            paginationStyle: .inline
        )

        guard let template = paginatedList.listTemplate else {
            fatalError("Expected CarPlayPaginatedListTemplate to create a CPListTemplate")
        }
        self.template = template
        template.tabTitle = title
        template.tabImage = tabImage
        template.tabSystemItem = .more

        self.viewModel.templateProvider = self
        presentEmptyState()
    }

    private var isFolderSource: Bool {
        if case .folder = viewModel.source {
            return true
        }
        return false
    }

    private lazy var addItemFooterRow: CPListItem = makeAddItemRow(destination: mainDestination)
    private lazy var editItemFooterRow: CPListItem = makeEditItemRow(destination: mainDestination)

    // A tab's root template in a CPTabBarTemplate doesn't render nav-bar buttons, so the add affordance
    // is a list row appended to the end of the Quick Access list instead.
    private func makeAddItemRow(destination: CarPlayAddItemViewModel.Destination) -> CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.QuickAccess.AddItem.button,
            detailText: nil,
            image: MaterialDesignIcons.plusCircleOutlineIcon.carPlayIcon()
        )
        item.handler = { [weak self] _, completion in
            self?.presentAddItemFlow(destination: destination)
            completion()
        }
        return item
    }

    private func makeEditItemRow(destination: CarPlayAddItemViewModel.Destination) -> CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.QuickAccess.EditItem.button,
            detailText: L10n.CarPlay.QuickAccess.EditItem.subtitle,
            image: MaterialDesignIcons.pencilCircleOutlineIcon.carPlayIcon()
        )
        item.handler = { [weak self] _, completion in
            self?.presentEditItemFlow(destination: destination)
            completion()
        }
        return item
    }

    /// Where this template's own add/edit affordances write: the Quick Access list, or — when the
    /// template renders a folder tab — that folder.
    private var mainDestination: CarPlayAddItemViewModel.Destination {
        switch viewModel.source {
        case .quickAccess:
            return .quickAccess
        case let .folder(folderId):
            return .folder(folderId: folderId)
        }
    }

    private func presentAddItemFlow(destination: CarPlayAddItemViewModel.Destination) {
        let flow = CarPlayAddItemFlow(
            interfaceController: interfaceController,
            viewModel: CarPlayAddItemViewModel(destination: destination)
        ) { [weak self] in
            // Defer release so the flow isn't deallocated mid-callback.
            DispatchQueue.main.async { self?.addItemFlow = nil }
        }
        addItemFlow = flow
        flow.start()
    }

    private func presentEditItemFlow(destination: CarPlayAddItemViewModel.Destination) {
        let entityToAreaMap = entityToAreaMap()
        let flow = CarPlayEditItemFlow(
            interfaceController: interfaceController,
            viewModel: CarPlayAddItemViewModel(destination: destination),
            itemDisplay: { [weak self] item in
                guard let self,
                      let displayItem = rowDisplayItem(for: item, entityToAreaMap: entityToAreaMap) else {
                    let info = self?.info(for: item) ?? .init(
                        id: item.id,
                        name: item.id,
                        iconName: "",
                        customization: nil
                    )
                    return (
                        title: item.name(info: info),
                        subtitle: self?.subtitle(for: item),
                        image: item.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor))
                    )
                }

                return (
                    title: displayItem.title,
                    subtitle: editSubtitle(for: item, entityToAreaMap: entityToAreaMap) ?? displayItem.subtitle,
                    image: displayItem.image
                )
            },
            onFinish: { [weak self] in
                // Defer release so the flow isn't deallocated mid-callback.
                DispatchQueue.main.async { self?.editItemFlow = nil }
            }
        )
        editItemFlow = flow
        flow.start()
    }

    func templateWillDisappear(template: CPTemplate) {
        if #available(iOS 26.4, *),
           let activeAssistSession = activeAssistSession as? CarPlayAssistSession {
            activeAssistSession.templateWillDisappear(template: template)
        }
        if template == self.template {
            /* no-op */
        }
        climateControlTemplate?.templateWillDisappear(template: template)
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            // Returning to this template means any folder list or control screen pushed from it
            // has been popped.
            openFolderTemplates.removeAll()
            folderListItemsByKey.removeAll()
            folderFooterRows.removeAll()
            climateControlTemplate = nil
            update()
        }
        climateControlTemplate?.templateWillAppear(template: template)
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        let previousEntities = entitiesPerServer[serverId]
        entitiesPerServer[serverId] = entities
        climateControlTemplate?.entitiesStateChange(serverId: serverId, entities: entities)
        guard !currentItems.isEmpty else { return }
        guard hasRelevantEntityChange(serverId: serverId, previous: previousEntities, current: entities) else {
            return
        }
        refreshCurrentPresentation()
    }

    private func hasRelevantEntityChange(
        serverId: String,
        previous: HACachedStates?,
        current: HACachedStates
    ) -> Bool {
        guard let previous else { return true }
        // Folder children live one level deep and render in pushed folder lists.
        var entityItems: [MagicItem] = []
        for item in currentItems {
            if item.type == .entity, item.serverId == serverId {
                entityItems.append(item)
            }
            for child in item.items ?? [] where child.type == .entity && child.serverId == serverId {
                entityItems.append(child)
            }
        }
        guard !entityItems.isEmpty else { return false }
        return entityItems.contains { magicItem in
            let old = previous[magicItem.id]
            let new = current[magicItem.id]
            return old?.state != new?.state || old?.lastUpdated != new?.lastUpdated
        }
    }

    private func executionKey(for magicItem: MagicItem) -> String {
        magicItem.serverUniqueId
    }

    private func rowCacheKey(for magicItem: MagicItem) -> String {
        "\(magicItem.serverUniqueId)-\(magicItem.type.rawValue)"
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

    func updateList(for items: [MagicItem], layout: CarPlayQuickAccessLayout, showAddEditButtons: Bool) {
        currentItems = items
        currentLayout = layout
        currentShowAddEditButtons = showAddEditButtons
        pruneLastKnownEntities(for: items)
        guard !items.isEmpty else {
            presentEmptyState()
            return
        }
        refreshCurrentPresentation()
    }

    private func presentEmptyState() {
        guard !isFolderSource else {
            presentEmptyFolderState()
            return
        }

        guard currentShowAddEditButtons else {
            presentAddEditHiddenEmptyState()
            return
        }

        if #available(iOS 26.0, *), currentLayout == .grid {
            paginatedList.updateItems(items: rowItems(displayItems: actionDisplayItems(includeEdit: false)))
        } else {
            template.trailingNavigationBarButtons = []
            template.updateSections([.init(items: [makeAddItemRow(destination: mainDestination)])])
        }
    }

    private func presentAddEditHiddenEmptyState() {
        let item = CPListItem(
            text: L10n.CarPlay.QuickAccess.Empty.title,
            detailText: L10n.CarPlay.QuickAccess.Empty.body
        )
        template.trailingNavigationBarButtons = []
        template.updateSections([.init(items: [item])])
    }

    /// Empty state of a folder tab: offer to add items into the folder from the car, matching the
    /// Quick Access tab's empty state; an info row when the add/edit affordances are hidden.
    private func presentEmptyFolderState() {
        template.trailingNavigationBarButtons = []
        if currentShowAddEditButtons {
            template.updateSections([.init(items: [makeAddItemRow(destination: mainDestination)])])
        } else {
            let item = CPListItem(
                text: L10n.CarPlay.Folder.Empty.title,
                detailText: L10n.CarPlay.QuickAccess.Empty.body
            )
            template.updateSections([.init(items: [item])])
        }
    }

    private func refreshCurrentPresentation() {
        defer { refreshOpenFolderTemplates() }

        guard !currentItems.isEmpty else {
            presentEmptyState()
            return
        }

        if #available(iOS 26.0, *), currentLayout == .grid {
            paginatedList.updateItems(
                items: rowItems(displayItems: gridItems(items: currentItems)),
                footerItems: gridActionFooterItems()
            )
        } else {
            paginatedList.updateItems(
                items: listItems(items: currentItems),
                footerItems: currentShowAddEditButtons ? [addItemFooterRow, editItemFooterRow] : []
            )
        }
    }

    @available(iOS 26.0, *)
    private func gridActionFooterItems() -> [any CPListTemplateItem] {
        guard currentShowAddEditButtons else { return [] }
        return rowItems(displayItems: actionDisplayItems(includeEdit: true))
    }

    private func listItems(items: [MagicItem]) -> [CPListItem] {
        var cache = listItemsByKey
        let rows = buildRows(items: items, cache: &cache)
        listItemsByKey = cache
        return rows
    }

    /// Builds list rows for the given items, reusing rows from `cache` and updating them in place —
    /// recreating rows resets the focused row on rotary-controlled (non-touch) displays. The cache
    /// is replaced with the rows that are still in use.
    private func buildRows(items: [MagicItem], cache: inout [String: CPListItem]) -> [CPListItem] {
        let entityToAreaMap = entityToAreaMap()
        var updatedItemsByKey: [String: CPListItem] = [:]
        var rows: [CPListItem] = []
        rows.reserveCapacity(items.count)

        for magicItem in items {
            let key = rowCacheKey(for: magicItem)
            let item = cache[key] ?? CPListItem(text: nil, detailText: nil)

            switch magicItem.type {
            case .entity:
                configureEntityRow(item, for: magicItem, entityToAreaMap: entityToAreaMap)
            case .folder:
                configureFolderRow(item, for: magicItem)
            case .assistPipeline, .assistPrompt:
                configureAssistRow(item, for: magicItem)
            default:
                configureDefaultRow(item, for: magicItem)
            }

            updatedItemsByKey[key] = item
            rows.append(item)
        }

        cache = updatedItemsByKey
        return rows
    }

    private func configureEntityRow(_ item: CPListItem, for magicItem: MagicItem, entityToAreaMap: [String: String]) {
        let info = info(for: magicItem)
        if let rowDisplayItem = rowDisplayItem(for: magicItem, entityToAreaMap: entityToAreaMap) {
            item.setText(rowDisplayItem.title)
            item.setImage(rowDisplayItem.image)
            if isExecuting(magicItem) {
                item.setDetailText(CarPlayEntityListItem.executingSubtitle)
            } else {
                item.setDetailText(rowDisplayItem.subtitle)
            }
        } else {
            item.setText("")
            item.setDetailText("")
            item.setImage(nil)
        }
        item.handler = { [weak self] _, _ in
            guard let self else { return }
            itemTap(
                magicItem: magicItem,
                info: info,
                currentItemState: resolvedEntity(for: magicItem)?.state ?? "",
                executionStarted: { [weak self] in self?.beginExecuting(magicItem) },
                executionFinished: { [weak self] in self?.endExecuting(magicItem) }
            )
        }
    }

    private func configureFolderRow(_ item: CPListItem, for magicItem: MagicItem) {
        let info = info(for: magicItem)
        item.setText(magicItem.name(info: info))
        item.setDetailText(nil)
        item.setImage(magicItem.icon(info: info).carPlayIcon(color: UIColor(hex: info.customization?.iconColor)))
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentFolderContents(folder: magicItem)
            completion()
        }
    }

    private func configureAssistRow(_ item: CPListItem, for magicItem: MagicItem) {
        let info = info(for: magicItem)
        item.setText(assistTitle(for: magicItem, info: info))
        item.setDetailText(assistSubtitle(for: magicItem, info: info))
        item.setImage(magicItem.icon(info: info).carPlayIcon(color: iconColor(for: info)))
        item.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }
            presentAssistSession(magicItem: magicItem, info: info)
            completion()
        }
    }

    private func configureDefaultRow(_ item: CPListItem, for magicItem: MagicItem) {
        let info = info(for: magicItem)
        item.setText(magicItem.name(info: info))
        item.setDetailText(renderedSubtitle(for: magicItem, defaultSubtitle: subtitle(for: magicItem)))
        item.setImage(magicItem.icon(info: info).carPlayIcon(color: UIColor(hex: info.customization?.iconColor)))
        item.handler = { [weak self] _, _ in
            guard let self else { return }
            itemTap(
                magicItem: magicItem,
                info: info,
                executionStarted: { [weak self] in self?.beginExecuting(magicItem) },
                executionFinished: { [weak self] in self?.endExecuting(magicItem) }
            )
        }
    }

    private func presentFolderContents(folder: MagicItem) {
        let folderInfo = info(for: folder)
        let listTemplate = CPListTemplate(title: folder.name(info: folderInfo), sections: [])
        openFolderTemplates.append((folderId: folder.id, template: listTemplate))
        updateFolderContents(folder: folder, in: listTemplate)
        interfaceController?.pushTemplate(listTemplate, animated: true, completion: nil)
    }

    private func updateFolderContents(folder: MagicItem, in template: CPListTemplate) {
        let footerRows = folderFooterRows(for: folder)

        // Folders can't nest in CarPlay; drop any stray nested folders defensively.
        let items = (folder.items ?? []).filter { $0.type != .folder }
        guard !items.isEmpty else {
            folderListItemsByKey[folder.id] = nil
            if let addRow = footerRows.first {
                applyFolderSections(rows: [addRow], to: template)
            } else {
                template.updateSections([.init(items: [CPListItem(
                    text: L10n.CarPlay.Folder.Empty.title,
                    detailText: L10n.CarPlay.QuickAccess.Empty.body
                )])])
            }
            return
        }

        var cache = folderListItemsByKey[folder.id] ?? [:]
        let rows = buildRows(items: items, cache: &cache)
        folderListItemsByKey[folder.id] = cache

        let maxItems = max(1, Int(CPListTemplate.maximumItemCount) - footerRows.count)
        if rows.count > maxItems {
            Current.Log.error("CarPlay folder list of \(rows.count) exceeds \(maxItems); truncating")
        }
        applyFolderSections(rows: Array(rows.prefix(maxItems)) + footerRows, to: template)
    }

    /// Add/Edit rows targeting the given folder, cached per folder so refreshed lists keep the
    /// same row instances. Empty when the add/edit affordances are hidden.
    private func folderFooterRows(for folder: MagicItem) -> [CPListItem] {
        guard currentShowAddEditButtons else {
            folderFooterRows[folder.id] = nil
            return []
        }
        if let rows = folderFooterRows[folder.id] {
            return rows
        }
        let destination = CarPlayAddItemViewModel.Destination.folder(folderId: folder.id)
        let rows = [makeAddItemRow(destination: destination), makeEditItemRow(destination: destination)]
        folderFooterRows[folder.id] = rows
        return rows
    }

    /// Skips `updateSections` when the rows are the same instances — reloading resets the focused
    /// row on rotary-controlled (non-touch) displays.
    private func applyFolderSections(rows: [CPListItem], to template: CPListTemplate) {
        let existingItems = template.sections.flatMap(\.items)
        let isIdentical = existingItems.count == rows.count && zip(existingItems, rows)
            .allSatisfy { ($0.0 as AnyObject) === ($0.1 as AnyObject) }
        if isIdentical {
            return
        }
        template.updateSections([CPListSection(items: rows)])
    }

    private func refreshOpenFolderTemplates() {
        for entry in openFolderTemplates {
            guard let folder = currentItems.first(where: { $0.type == .folder && $0.id == entry.folderId }) else {
                continue
            }
            updateFolderContents(folder: folder, in: entry.template)
        }
    }

    @available(iOS 26.0, *)
    private func gridItems(items: [MagicItem]) -> [CondensedDisplayItem] {
        let entityToAreaMap = entityToAreaMap()
        return items.compactMap { magicItem in
            guard let displayItem = rowDisplayItem(for: magicItem, entityToAreaMap: entityToAreaMap) else {
                return nil
            }

            return CondensedDisplayItem(
                image: displayItem.image,
                iconColor: displayItem.iconColor,
                title: displayItem.title,
                subtitle: displayItem.subtitle,
                accessorySymbolName: magicItem.type == .folder ? "chevron.forward" : nil,
                handler: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }

                    if displayItem.magicItem.type == .folder {
                        presentFolderContents(folder: displayItem.magicItem)
                    } else if isAssistItem(displayItem.magicItem) {
                        presentAssistSession(magicItem: displayItem.magicItem, info: displayItem.info)
                    } else {
                        itemTap(
                            magicItem: displayItem.magicItem,
                            info: displayItem.info,
                            currentItemState: displayItem.currentState,
                            executionStarted: { [weak self] in self?.beginExecuting(displayItem.magicItem) },
                            executionFinished: { [weak self] in self?.endExecuting(displayItem.magicItem) }
                        )
                    }
                    completion()
                }
            )
        }
    }

    @available(iOS 26.0, *)
    private func actionDisplayItems(includeEdit: Bool) -> [CondensedDisplayItem] {
        var items = [CondensedDisplayItem(
            image: MaterialDesignIcons.plusCircleOutlineIcon.carPlayIcon(),
            iconColor: nil,
            title: L10n.CarPlay.QuickAccess.AddItem.button,
            subtitle: nil,
            accessorySymbolName: nil,
            handler: { [weak self] completion in
                guard let self else {
                    completion()
                    return
                }
                presentAddItemFlow(destination: mainDestination)
                completion()
            }
        )]

        if includeEdit {
            items.append(CondensedDisplayItem(
                image: MaterialDesignIcons.pencilCircleOutlineIcon.carPlayIcon(),
                iconColor: nil,
                title: L10n.CarPlay.QuickAccess.EditItem.button,
                subtitle: L10n.CarPlay.QuickAccess.EditItem.subtitle,
                accessorySymbolName: nil,
                handler: { [weak self] completion in
                    guard let self else {
                        completion()
                        return
                    }
                    presentEditItemFlow(destination: mainDestination)
                    completion()
                }
            ))
        }

        return items
    }

    @available(iOS 26.0, *)
    private func rowItems(displayItems: [CondensedDisplayItem]) -> [any CPListTemplateItem] {
        stride(from: 0, to: displayItems.count, by: CarPlayCondensedEntitiesGroup.size).map { startIndex in
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
                    accessorySymbolName: item.accessorySymbolName
                )
            }

            let rowItem = CPListImageRowItem(
                text: nil,
                condensedElements: elements,
                allowsMultipleLines: true
            )
            rowItem.listImageRowHandler = { _, index, completion in
                guard pageItems.indices.contains(index) else {
                    completion()
                    return
                }

                pageItems[index].handler(completion)
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
        // Domains without a single tap action (climate) push their own control screen.
        if magicItem.type == .entity, Domain(entityId: magicItem.id)?.hasControlScreen == true {
            presentClimateControl(magicItem: magicItem)
            return
        }

        // Check if this is a lock entity - locks always require confirmation
        let isLockEntity = magicItem
            .type == .entity && Domain(entityId: magicItem.id) == .lock
        let supportsConfirmation = !isAssistItem(magicItem)

        if isLockEntity {
            // For lock entities, show lock-specific confirmation
            showLockConfirmation(magicItem: magicItem, info: info, currentState: currentItemState) { [weak self] in
                executionStarted()
                self?.executeLockEntity(magicItem, currentState: currentItemState, completion: executionFinished)
            }
        } else if supportsConfirmation, info.customization?.requiresConfirmation ?? false {
            showConfirmationForRunningMagicItem(item: magicItem, info: info) { [weak self] in
                executionStarted()
                self?.executeMagicItem(magicItem, completion: executionFinished)
            }
        } else {
            executionStarted()
            executeMagicItem(magicItem, completion: executionFinished)
        }
    }

    private func presentClimateControl(magicItem: MagicItem) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }) else {
            Current.Log.error("Failed to get server for climate magic item id: \(magicItem.id)")
            return
        }
        guard let entity = resolvedEntity(for: magicItem) else {
            Current.Log.error("Failed to resolve entity for climate magic item id: \(magicItem.id)")
            return
        }
        let provider = CarPlayClimateControlTemplate(viewModel: .init(server: server, entity: entity))
        provider.interfaceController = interfaceController
        climateControlTemplate = provider
        interfaceController?.pushTemplate(provider.template, animated: true, completion: nil)
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
        magicItem.execute(on: server, source: .CarPlay) { success, _ in
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

    private func editSubtitle(for magicItem: MagicItem, entityToAreaMap: [String: String]) -> String? {
        guard magicItem.type == .entity else {
            return subtitle(for: magicItem)
        }

        return entityContextSubtitle(
            for: magicItem,
            stateSubtitle: nil,
            entityToAreaMap: entityToAreaMap
        )
    }

    private func entityContextSubtitle(
        for magicItem: MagicItem,
        stateSubtitle: String?,
        entityToAreaMap: [String: String]
    ) -> String? {
        let serverName = subtitle(for: magicItem)
        let areaName = area(for: magicItem, entityToAreaMap: entityToAreaMap)
        let stateSubtitle = stateSubtitleWithoutArea(stateSubtitle, areaName: areaName)
        let serverSubtitle = shouldShowServerInEntitySubtitle ? serverName : nil

        let subtitle = [stateSubtitle, serverSubtitle, areaName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        return subtitle.isEmpty ? nil : subtitle
    }

    private var shouldShowServerInEntitySubtitle: Bool {
        Set(currentItems.filter { $0.type == .entity }.map(\.serverId)).count > 1
    }

    private func stateSubtitleWithoutArea(_ stateSubtitle: String?, areaName: String?) -> String? {
        guard let stateSubtitle = stateSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              let areaName = areaName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !areaName.isEmpty else {
            return stateSubtitle
        }

        let areaSuffix = " • \(areaName)"
        guard stateSubtitle.hasSuffix(areaSuffix) else { return stateSubtitle }

        return String(stateSubtitle.dropLast(areaSuffix.count))
    }

    private func isAssistItem(_ magicItem: MagicItem) -> Bool {
        magicItem.type == .assistPipeline || magicItem.type == .assistPrompt
    }

    private func assistTitle(for magicItem: MagicItem, info: MagicItem.Info) -> String {
        magicItem.name(info: info)
    }

    private func assistSubtitle(for magicItem: MagicItem, info: MagicItem.Info) -> String? {
        let pipelineTitle = magicItem.name(info: info)

        if magicItem.type == .assistPrompt {
            guard let assistPrompt = magicItem.assistPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !assistPrompt.isEmpty else {
                return nil
            }

            return assistPrompt
        }

        let assistLabel = L10n.Widgets.Action.Name.assist
        return pipelineTitle == assistLabel ? nil : assistLabel
    }

    private func iconColor(for info: MagicItem.Info) -> UIColor {
        guard let iconColorHex = info.customization?.iconColor else { return .haPrimary }
        return UIColor(hex: iconColorHex)
    }

    private func renderedSubtitle(for magicItem: MagicItem, defaultSubtitle: String?) -> String? {
        isExecuting(magicItem) ? CarPlayEntityListItem.executingSubtitle : defaultSubtitle
    }

    private func entityCacheKey(serverId: String, entityId: String) -> String {
        "\(serverId)::\(entityId)"
    }

    private func pruneLastKnownEntities(for items: [MagicItem]) {
        let validKeys = Set(
            items
                .filter { $0.type == .entity }
                .map { entityCacheKey(serverId: $0.serverId, entityId: $0.id) }
        )
        lastKnownEntities = lastKnownEntities.filter { validKeys.contains($0.key) }
    }

    private func resolvedEntity(for magicItem: MagicItem) -> HAEntity? {
        let cacheKey = entityCacheKey(serverId: magicItem.serverId, entityId: magicItem.id)

        if let entity = entitiesPerServer[magicItem.serverId]?[magicItem.id] {
            lastKnownEntities[cacheKey] = entity
            return entity
        }

        if let entity = lastKnownEntities[cacheKey] {
            return entity
        }

        return placeholderEntity(id: magicItem.id)
    }

    private func rowDisplayItem(
        for magicItem: MagicItem,
        entityToAreaMap: [String: String]
    ) -> RowDisplayItem? {
        let info = info(for: magicItem)

        switch magicItem.type {
        case .entity:
            guard let entity = resolvedEntity(for: magicItem) else {
                Current.Log.error("Failed to create placeholder entity for magic item id: \(magicItem.id)")
                return nil
            }

            let area = area(for: magicItem, entityToAreaMap: entityToAreaMap)
            let entityProvider = CarPlayEntityListItem(
                serverId: magicItem.serverId,
                entity: entity,
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
                subtitle: renderedSubtitle(
                    for: magicItem,
                    defaultSubtitle: entityContextSubtitle(
                        for: magicItem,
                        stateSubtitle: content.subtitle,
                        entityToAreaMap: entityToAreaMap
                    )
                ),
                currentState: entityProvider.entity.state
            )
        case .assistPipeline, .assistPrompt:
            let iconColor = iconColor(for: info)
            return RowDisplayItem(
                magicItem: magicItem,
                info: info,
                image: magicItem.icon(info: info).carPlayIcon(color: iconColor),
                iconColor: iconColor,
                title: assistTitle(for: magicItem, info: info),
                subtitle: assistSubtitle(for: magicItem, info: info),
                currentState: ""
            )
        default:
            let iconColor = iconColor(for: info)
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
            let serverId = server.identifier.rawValue
            let areas: [AppArea]
            do {
                areas = try AppArea.fetchAreas(for: serverId)
            } catch {
                Current.Log.error("Failed to fetch areas for CarPlay quick access: \(error.localizedDescription)")
                areas = []
            }
            for area in areas {
                for entityId in area.entities {
                    entityToAreaMap[entityCacheKey(serverId: serverId, entityId: entityId)] = area.name
                }
            }
        }
        return entityToAreaMap
    }

    private func area(for magicItem: MagicItem, entityToAreaMap: [String: String]) -> String? {
        entityToAreaMap[entityCacheKey(serverId: magicItem.serverId, entityId: magicItem.id)]
    }

    private func presentAssistSession(magicItem: MagicItem, info: MagicItem.Info) {
        guard #available(iOS 26.4, *) else { return }

        // Stop any existing session before starting a new one
        (activeAssistSession as? CarPlayAssistSession)?.stop()
        activeAssistSession = nil

        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
            Current.Log.error("Failed to get server for assist item: \(magicItem.id)")
            return
        }
        let session = CarPlayAssistSession(
            interfaceController: interfaceController,
            server: server,
            pipelineId: magicItem.assistPipelineId ?? magicItem.id,
            prompt: magicItem.type == .assistPrompt ? magicItem.assistPrompt : nil
        )
        session.onStop = { [weak self] in
            self?.activeAssistSession = nil
        }
        activeAssistSession = session
        session.start()
    }
}
