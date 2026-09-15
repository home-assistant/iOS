import Foundation

/// Builds one room's screen: what it can light, heat, lock and play, then everything else in it
/// grouped by the device it belongs to. The port of the frontend's `home-area-view-strategy`.
public enum HomeAreaStrategy {
    /// The summaries the area view groups its entities by, in the order it draws them.
    private static let groupedSummaries: [HomeSummaryKind] = [.light, .climate, .security, .mediaPlayers]

    public static func generate(
        areaId: String,
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeDashboardViewConfig? {
        guard let area = registry.area(areaId) else {
            return nil
        }

        let areaEntities = registry.allEntityIds.filter { entityId in
            HomeEntityFilterMatcher.matches(
                entityId: entityId,
                filter: HomeEntityFilter(areas: [areaId]),
                registry: registry
            )
        }

        var entitiesBySummary: [HomeSummaryKind: [String]] = [:]
        for summary in HomeSummaryKind.allCases where summary != .weather {
            entitiesBySummary[summary] = HomeEntityFilterMatcher.find(
                in: areaEntities,
                matching: HomeSummaryFilters.filters(for: summary),
                registry: registry
            )
        }

        var sections: [HomeDashboardSectionConfig] = []

        for summary in groupedSummaries {
            let entities = entitiesBySummary[summary] ?? []
            guard !entities.isEmpty else {
                continue
            }
            sections.append(HomeDashboardSectionConfig(
                id: summary.rawValue,
                cards: [.heading(heading(
                    for: summary,
                    areaId: areaId,
                    entities: entities,
                    registry: registry,
                    strings: strings
                ))]
                    + entities.map { card(for: $0, area: area, registry: registry) }
            ))
        }

        let scenes = areaEntities.filter {
            HomeEntityFilterMatcher.matches(entityId: $0, filter: .domain("scene"), registry: registry)
        }
        if !scenes.isEmpty {
            sections.append(HomeDashboardSectionConfig(
                id: "scenes",
                cards: [.heading(.init(
                    id: "scenes",
                    heading: strings.scenes,
                    icon: "mdi:palette",
                    tapAction: registry.isAdmin ? .navigate("/config/scene/dashboard") : nil
                ))] + scenes.map { card(for: $0, area: area, registry: registry) }
            ))
        }

        let automations = areaEntities.filter {
            HomeEntityFilterMatcher.matches(entityId: $0, filter: .domain("automation"), registry: registry)
        }

        // Maintenance is left out on purpose: a battery belongs to its device's section, where the
        // heading shows it as a badge, not to a section of its own.
        let claimed = Set(
            entitiesBySummary.filter { $0.key != .maintenance }.values.flatMap { $0 } + scenes + automations
        )
        let deviceSections = deviceSections(
            entities: areaEntities.filter { !claimed.contains($0) },
            area: area,
            registry: registry,
            strings: strings
        )
        if !deviceSections.isEmpty {
            // An empty subtitle, which is how the web dashboard puts air between the room's controls
            // and the list of its devices.
            sections.append(HomeDashboardSectionConfig(
                id: "devices-separator",
                cards: [.heading(.init(id: "devices-separator", heading: "", style: .subtitle))],
                columnSpan: 3
            ))
            sections.append(contentsOf: deviceSections)
        }

        if !automations.isEmpty {
            sections.append(HomeDashboardSectionConfig(
                id: "automations",
                cards: [.heading(.init(
                    id: "automations",
                    heading: strings.automations,
                    icon: "mdi:robot",
                    tapAction: registry.isAdmin ? .navigate("/config/automation/dashboard") : nil
                ))] + automations.map { card(for: $0, area: area, registry: registry) }
            ))
        }

        let badges = badges(for: area)

        guard !sections.isEmpty else {
            return HomeDashboardViewConfig(
                path: HomeDashboardPath.area(areaId),
                title: area.name,
                icon: area.icon,
                isSubview: true,
                content: .panel([.emptyState(emptyState(
                    area: area,
                    config: config,
                    registry: registry,
                    strings: strings
                ))]),
                badges: badges
            )
        }

        // Between two and three columns. One section takes two so the header above it is not squeezed
        // into a narrow strip on a wide screen.
        let maxColumns = min(max(sections.count, 2), 3)
        return HomeDashboardViewConfig(
            path: HomeDashboardPath.area(areaId),
            title: area.name,
            icon: area.icon,
            isSubview: true,
            content: .sections(sections),
            badges: badges,
            maxColumns: maxColumns
        )
    }

    // MARK: - Cards

    /// A tile, or a picture when the entity is a camera — a camera is worth seeing rather than
    /// reading.
    private static func card(for entityId: String, area: HomeArea, registry: HomeRegistry) -> HomeDashboardCardConfig {
        let name = registry.state(entityId)
            .map(HomeEntityNameFormatter.name(of:))
            .flatMap { HomeEntityNameFormatter.strippingPrefix(area.name, from: $0) }

        if HomeEntityID.domain(of: entityId) == "camera" {
            return .pictureEntity(HomePictureEntityCardConfig(entityId: entityId, name: name))
        }
        return .tile(HomeTileCardConfig(
            entityId: entityId,
            name: name,
            feature: registry.state(entityId).flatMap(HomeTileFeatureResolver.feature(for:))
        ))
    }

    private static func heading(
        for summary: HomeSummaryKind,
        areaId: String,
        entities: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeHeadingCardConfig {
        HomeHeadingCardConfig(
            id: summary.rawValue,
            heading: strings.title(for: summary),
            icon: summary.icon,
            tapAction: headingAction(for: summary, registry: registry),
            badges: summary == .light ? lightBadges(areaId: areaId, entities: entities, strings: strings) : []
        )
    }

    private static func headingAction(for summary: HomeSummaryKind, registry: HomeRegistry) -> HomeDashboardAction? {
        switch summary {
        case .light: registry.hasPanel("light") ? .navigate("/light?historyBack=1") : nil
        case .climate: registry.hasPanel("climate") ? .navigate("/climate?historyBack=1") : nil
        case .security: registry.hasPanel("security") ? .navigate("/security?historyBack=1") : nil
        case .mediaPlayers: .navigate("\(HomeDashboardPath.mediaPlayers)?historyBack=1")
        case .maintenance, .energy, .persons, .weather: nil
        }
    }

    /// The pair of buttons over a room's lights: one to turn them on while they are all off, one to
    /// turn them off while any is on. Only ever one of them is visible.
    private static func lightBadges(
        areaId: String,
        entities: [String],
        strings: HomeDashboardStrings
    ) -> [HomeHeadingBadgeConfig] {
        [
            .button(HomeHeadingButtonBadgeConfig(
                id: "lights-state-off",
                icon: "mdi:power",
                text: strings.lightsOff,
                tapAction: .performAction(HomeServiceCall(service: "light.turn_on", areaId: areaId)),
                visibility: .noneOn(entities)
            )),
            .button(HomeHeadingButtonBadgeConfig(
                id: "lights-state-on",
                icon: "mdi:power",
                text: strings.lightsOn,
                color: "orange",
                tapAction: .performAction(HomeServiceCall(service: "light.turn_off", areaId: areaId)),
                visibility: .anyOn(entities)
            )),
        ]
    }

    private static func badges(for area: HomeArea) -> [HomeEntityBadgeConfig] {
        var badges: [HomeEntityBadgeConfig] = []
        if let temperature = area.temperatureEntityId {
            badges.append(HomeEntityBadgeConfig(entityId: temperature, color: "red"))
        }
        if let humidity = area.humidityEntityId {
            badges.append(HomeEntityBadgeConfig(entityId: humidity, color: "indigo"))
        }
        return badges
    }

    // MARK: - Whatever is left

    /// Everything the room holds that no section claimed, grouped by the device it belongs to, with
    /// the device's battery shown beside its name. Devices with nothing but configuration entities
    /// are dropped.
    private static func deviceSections(
        entities: [String],
        area: HomeArea,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> [HomeDashboardSectionConfig] {
        var byDevice: [String: [String]] = [:]
        var deviceOrder: [String] = []
        var unassigned: [String] = []

        for entityId in entities {
            guard let device = registry.context(of: entityId).device else {
                unassigned.append(entityId)
                continue
            }
            if byDevice[device.id] == nil {
                deviceOrder.append(device.id)
            }
            byDevice[device.id, default: []].append(entityId)
        }

        let battery = HomeEntityFilter(domains: ["sensor"], deviceClasses: ["battery"])
        let primary = HomeEntityFilter(entityCategories: [.none])
        var sections: [HomeDashboardSectionConfig] = []

        for deviceId in deviceOrder + (unassigned.isEmpty ? [] : ["unassigned"]) {
            let deviceEntities = deviceId == "unassigned" ? unassigned : (byDevice[deviceId] ?? [])
            let batteries = deviceEntities.filter {
                HomeEntityFilterMatcher.matches(entityId: $0, filter: battery, registry: registry)
            }
            let shown = deviceEntities.filter {
                !HomeEntityFilterMatcher.matches(entityId: $0, filter: battery, registry: registry)
                    && HomeEntityFilterMatcher.matches(entityId: $0, filter: primary, registry: registry)
            }
            guard !shown.isEmpty else {
                continue
            }

            let device = registry.device(deviceId)
            let heading = device.map { $0.displayName ?? strings.unnamedDevice } ?? strings.others
            sections.append(HomeDashboardSectionConfig(
                id: "device:\(deviceId)",
                cards: [.heading(.init(
                    id: "device:\(deviceId)",
                    heading: heading,
                    tapAction: registry
                        .isAdmin && device != nil ? .navigate("/config/devices/device/\(deviceId)") : nil,
                    badges: batteries.prefix(1).map { .entity(.init(entityId: $0, tapAction: .moreInfo($0))) }
                ))] + shown.map { card(for: $0, area: area, registry: registry) }
            ))
        }
        return sections
    }

    private static func emptyState(
        area: HomeArea,
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
                    action: .navigate(HomeDashboardPath.addIntegration)
                ),
                HomeEmptyStateButtonConfig(
                    id: "assign-device",
                    icon: "mdi:home-plus",
                    text: strings.assignDevice,
                    action: .navigate("/home/\(HomeDashboardPath.otherDevices)")
                ),
            ]
        }
        return HomeEmptyStateCardConfig(
            icon: area.icon ?? "mdi:shape-square-rounded-plus",
            title: strings.areaNoDevicesTitle,
            content: strings.areaNoDevicesContent,
            buttons: buttons
        )
    }
}
