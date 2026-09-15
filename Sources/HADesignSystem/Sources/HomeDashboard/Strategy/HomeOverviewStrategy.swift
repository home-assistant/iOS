import Foundation

/// Builds the dashboard's first screen: the greeting, the summaries, the favourites and every room
/// grouped by the floor it is on. The port of the frontend's `home-overview-view-strategy`.
///
/// Two things the web version does are deliberately absent, because both need data this app does not
/// hold: the suggested-entities row (which comes from the server's usage prediction) and the
/// admin-only repairs, updates and discovered-devices cards. Favourites the user pinned are shown.
public enum HomeOverviewStrategy {
    /// The web dashboard's widest layout, kept so a Mac window knows how far the grid may grow.
    static let maxColumns = 3

    public static func generate(
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeDashboardViewConfig {
        let hierarchy = HomeAreasFloorHierarchy.build(floors: registry.floors, areas: registry.areas)
        let headingCount = hierarchy.headingCount
        var sections: [HomeDashboardSectionConfig] = []

        if let favorites = favoritesSection(config: config, registry: registry, strings: strings) {
            sections.append(favorites)
        }

        let summaries = summaryCards(config: config, registry: registry, strings: strings)
        if !summaries.isEmpty {
            // The same summaries twice, once for each width: the web dashboard puts them in a
            // sidebar when there is room and in the flow when there is not.
            sections.append(HomeDashboardSectionConfig(
                id: "summaries",
                cards: [.heading(.init(id: "summaries", heading: strings.summaries))] + summaries,
                columnSpan: maxColumns,
                visibility: .smallScreen
            ))
            sections.append(HomeDashboardSectionConfig(
                id: "summaries-sidebar",
                cards: [.heading(.init(id: "summaries", heading: strings.summaries))] + summaries.map(\.fullWidth),
                visibility: .largeScreen
            ))
        }

        let floorSections = floorSections(
            hierarchy: hierarchy,
            headingCount: headingCount,
            registry: registry,
            strings: strings
        )
        sections.append(contentsOf: floorSections)

        guard !floorSections.isEmpty else {
            return HomeDashboardViewConfig(
                path: HomeDashboardPath.overview,
                icon: "mdi:home",
                content: .panel([.emptyState(emptyState(config: config, registry: registry, strings: strings))]),
                maxColumns: maxColumns
            )
        }

        return HomeDashboardViewConfig(
            path: HomeDashboardPath.overview,
            icon: "mdi:home",
            content: .sections(sections),
            header: config.hidesWelcomeMessage ? nil : HomeDashboardHeaderConfig(userName: registry.userName),
            maxColumns: maxColumns
        )
    }

    // MARK: - Areas by floor

    private static func floorSections(
        hierarchy: HomeAreasFloorHierarchy,
        headingCount: Int,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> [HomeDashboardSectionConfig] {
        var sections: [HomeDashboardSectionConfig] = []

        for floor in hierarchy.floors {
            let cards = floor.areaIds.compactMap { areaCard(areaId: $0, registry: registry) }
            guard !cards.isEmpty, let floorEntry = registry.floor(floor.id) else {
                continue
            }
            // One floor is not worth naming: the frontend calls the section "Areas" instead.
            let heading = headingCount > 1 ? floorEntry.name : strings.areas
            sections.append(HomeDashboardSectionConfig(
                id: "floor:\(floor.id)",
                cards: [.heading(.init(
                    id: "floor:\(floor.id)",
                    heading: heading,
                    icon: HomeFloorIcon.resolved(for: floorEntry)
                ))] + cards.map(HomeDashboardCardConfig.area),
                columnSpan: maxColumns
            ))
        }

        let looseCards = hierarchy.looseAreaIds.compactMap { areaCard(areaId: $0, registry: registry) }
        let showsOtherDevices = hasOtherDevices(registry: registry)

        guard !looseCards.isEmpty || showsOtherDevices else {
            return sections
        }

        var cards = looseCards.map(HomeDashboardCardConfig.area)
        if showsOtherDevices {
            // A tile over a zone entity, which every server has, standing in for "everything else".
            cards.append(.tile(HomeTileCardConfig(
                entityId: "zone.home",
                name: strings.devices,
                icon: "mdi:devices",
                isVertical: true,
                hidesState: true,
                tapAction: .navigate(HomeDashboardPath.otherDevices),
                columns: 4
            )))
        }

        let heading = looseHeading(hierarchy: hierarchy, strings: strings)
        sections.append(HomeDashboardSectionConfig(
            id: "areas",
            cards: (heading.map { [HomeDashboardCardConfig.heading(.init(id: "areas", heading: $0))] } ?? []) + cards,
            columnSpan: maxColumns
        ))
        return sections
    }

    /// What to call the section holding the areas on no floor. With no floors at all it is simply
    /// "Areas"; with floors above it, "Other areas"; and with no loose areas, it is the devices that
    /// are left over.
    private static func looseHeading(
        hierarchy: HomeAreasFloorHierarchy,
        strings: HomeDashboardStrings
    ) -> String? {
        let hasFloors = !hierarchy.floors.isEmpty
        let hasLooseAreas = !hierarchy.looseAreaIds.isEmpty
        switch (hasFloors, hasLooseAreas) {
        case (false, false): return nil
        case (false, true): return strings.areas
        case (true, false): return strings.devices
        case (true, true): return strings.otherAreas
        }
    }

    private static func areaCard(areaId: String, registry: HomeRegistry) -> HomeAreaCardConfig? {
        guard let area = registry.area(areaId) else {
            return nil
        }
        return HomeAreaCardConfig(
            areaId: area.id,
            name: area.name,
            icon: area.icon,
            sensorClasses: area.temperatureEntityId == nil ? [] : ["temperature"],
            tapAction: .navigate(HomeDashboardPath.area(area.id))
        )
    }

    /// Whether anything would end up in the "other devices" view — a primary entity with a device but
    /// no area. Without one the tile that opens it is not drawn at all.
    private static func hasOtherDevices(registry: HomeRegistry) -> Bool {
        let primary = HomeEntityFilter(entityCategories: [.none])
        return registry.allEntityIds.contains { entityId in
            HomeOtherDevicesFilters.filters.contains { filter in
                HomeEntityFilterMatcher.matches(entityId: entityId, filter: filter, registry: registry)
            }
                && HomeEntityFilterMatcher.matches(entityId: entityId, filter: primary, registry: registry)
                && registry.context(of: entityId).device != nil
        }
    }

    // MARK: - Favourites

    private static func favoritesSection(
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeDashboardSectionConfig? {
        let pinned = config.favoriteEntityIds.filter { registry.state($0) != nil }
        // The row holds eight, or however many the user pinned when that is more.
        let limit = max(8, pinned.count)
        var entities = pinned
        if !config.hidesSuggestedEntities, entities.count < limit {
            let suggested = config.suggestedEntityIds.filter { entityId in
                registry.state(entityId) != nil
                    && registry.entity(entityId)?.isHidden != true
                    && !pinned.contains(entityId)
            }
            entities.append(contentsOf: suggested)
        }
        entities = Array(entities.prefix(limit))

        guard !entities.isEmpty else {
            return nil
        }
        return HomeDashboardSectionConfig(
            id: "favorites",
            cards: [.heading(.init(id: "favorites", heading: strings.favorites))] + entities.map(favoriteCard),
            columnSpan: maxColumns
        )
    }

    /// A favourite is drawn without the control a room's tile gets, and with the room it is in named
    /// under it — it could be from anywhere in the house. A camera is worth its picture instead.
    private static func favoriteCard(_ entityId: String) -> HomeDashboardCardConfig {
        if HomeEntityID.domain(of: entityId) == "camera" {
            return .pictureEntity(HomePictureEntityCardConfig(entityId: entityId))
        }
        return .tile(HomeTileCardConfig(entityId: entityId, stateContent: [.state, .areaName]))
    }

    // MARK: - Summaries

    private static func summaryCards(
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> [HomeDashboardCardConfig] {
        let entityIds = registry.allEntityIds
        var cards: [HomeDashboardCardConfig] = []

        for summary in orderedSummaries(config: config) where !config.hiddenSummaries.contains(summary) {
            let matches = HomeEntityFilterMatcher.find(
                in: entityIds,
                matching: HomeSummaryFilters.filters(for: summary),
                registry: registry
            )
            guard let card = summaryCard(
                summary,
                entities: matches,
                config: config,
                registry: registry,
                strings: strings
            ) else {
                continue
            }
            cards.append(card)
        }
        return cards
    }

    /// The user's order, with any summary they never touched appended in the frontend's default
    /// order — exactly what `resolveShortcutItems` does.
    private static func orderedSummaries(config: HomeDashboardStrategyConfig) -> [HomeSummaryKind] {
        let defaults: [HomeSummaryKind] = [.light, .climate, .security, .mediaPlayers, .maintenance, .weather, .energy]
        var ordered = config.summaryOrder.filter(defaults.contains)
        ordered.append(contentsOf: defaults.filter { !ordered.contains($0) })
        return ordered
    }

    private static func summaryCard(
        _ summary: HomeSummaryKind,
        entities: [String],
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeDashboardCardConfig? {
        let title = strings.title(for: summary)
        switch summary {
        case .light:
            guard registry.hasPanel("light"), !entities.isEmpty else { return nil }
            return .summary(.init(
                summary: .light,
                title: title,
                entityIds: entities,
                tapAction: .navigate("/light?historyBack=1")
            ))
        case .climate:
            // Climate counts the area sensors too: a home with only a temperature sensor per room
            // still has something to say about its climate.
            let hasAreaSensors = registry.areas.contains { area in
                area.temperatureEntityId.flatMap(registry.state) != nil || area.humidityEntityId
                    .flatMap(registry.state) != nil
            }
            guard registry.hasPanel("climate"), !entities.isEmpty || hasAreaSensors else { return nil }
            return .summary(.init(
                summary: .climate,
                title: title,
                entityIds: entities,
                tapAction: .navigate("/climate?historyBack=1")
            ))
        case .security:
            guard registry.hasPanel("security"), !entities.isEmpty else { return nil }
            return .summary(.init(
                summary: .security,
                title: title,
                entityIds: entities,
                tapAction: .navigate("/security?historyBack=1")
            ))
        case .mediaPlayers:
            guard !entities.isEmpty else { return nil }
            return .summary(.init(
                summary: .mediaPlayers,
                title: title,
                entityIds: entities,
                tapAction: .navigate(HomeDashboardPath.mediaPlayers)
            ))
        case .maintenance:
            guard registry.hasPanel("maintenance"), !entities.isEmpty else { return nil }
            let path = config.isHomePanel ? "/maintenance?historyBack=1&backPath=/home" : "/maintenance?historyBack=1"
            return .summary(.init(summary: .maintenance, title: title, entityIds: entities, tapAction: .navigate(path)))
        case .weather:
            // The weather summary is a plain tile over the first weather entity, sorted by id so the
            // same one is picked every time.
            guard let weatherEntity = entities.sorted().first else { return nil }
            // The weather tile leads with the temperature, as `state_content` asks it to.
            return .tile(HomeTileCardConfig(entityId: weatherEntity, name: title, stateContent: [.temperature, .state]))
        case .energy:
            guard registry.hasPanel("energy"), registry.hasEnergyData else { return nil }
            let path = config.isHomePanel ? "/energy?historyBack=1&backPath=/home" : "/energy?historyBack=1"
            return .summary(.init(summary: .energy, title: title, tapAction: .navigate(path)))
        case .persons:
            guard !entities.isEmpty else { return nil }
            return .summary(.init(summary: .persons, title: title, entityIds: entities))
        }
    }

    // MARK: - Empty home

    private static func emptyState(
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeEmptyStateCardConfig {
        var buttons: [HomeEmptyStateButtonConfig] = []
        if config.isHomePanel, registry.isAdmin {
            buttons = [
                HomeEmptyStateButtonConfig(
                    id: "add-device",
                    icon: "mdi:plus",
                    text: strings.addDevice,
                    isProminent: true,
                    action: .navigate(HomeDashboardPath.addIntegration)
                ),
                HomeEmptyStateButtonConfig(
                    id: "edit-areas",
                    icon: "mdi:home-edit",
                    text: strings.editAreas,
                    action: .navigate("/config/areas/dashboard")
                ),
            ]
        }
        return HomeEmptyStateCardConfig(
            icon: "mdi:home-assistant",
            title: strings.noDevicesTitle,
            content: strings.noDevicesContent,
            buttons: buttons
        )
    }
}
