import Foundation

/// Every media player in the house, grouped by the room it is in. The port of the frontend's
/// `home-media-players-view-strategy`, reached from the overview's media summary.
public enum HomeMediaPlayersStrategy {
    public static func generate(registry: HomeRegistry, strings: HomeDashboardStrings) -> HomeDashboardViewConfig {
        let hierarchy = HomeAreasFloorHierarchy.build(floors: registry.floors, areas: registry.areas)
        let players = HomeEntityFilterMatcher.find(
            in: registry.allEntityIds,
            matching: HomeSummaryFilters.mediaPlayers,
            registry: registry
        )
        var sections: [HomeDashboardSectionConfig] = []

        for floor in hierarchy.floors {
            let cards = areaCards(areaIds: floor.areaIds, players: players, registry: registry)
            guard !cards.isEmpty, let floorEntry = registry.floor(floor.id) else {
                continue
            }
            let heading = hierarchy.headingCount > 1 ? floorEntry.name : strings.areas
            sections.append(HomeDashboardSectionConfig(
                id: "floor:\(floor.id)",
                cards: [.heading(.init(
                    id: "floor:\(floor.id)",
                    heading: heading,
                    icon: HomeFloorIcon.resolved(for: floorEntry)
                ))] + cards,
                columnSpan: 2
            ))
        }

        let looseCards = areaCards(areaIds: hierarchy.looseAreaIds, players: players, registry: registry)
        if !looseCards.isEmpty {
            sections.append(HomeDashboardSectionConfig(
                id: "areas",
                cards: [.heading(.init(
                    id: "areas",
                    heading: hierarchy.headingCount > 1 ? strings.otherAreas : strings.areas
                ))] + looseCards,
                columnSpan: 2
            ))
        }

        // Players that belong to no room at all go last, under a heading that only calls them
        // "other" when there was something before them.
        let unassigned = players.filter { registry.context(of: $0).area == nil }
        if !unassigned.isEmpty {
            sections.append(HomeDashboardSectionConfig(
                id: "unassigned",
                cards: [.heading(.init(
                    id: "unassigned",
                    heading: sections.isEmpty ? strings.mediaPlayers : strings.otherMediaPlayers
                ))] + unassigned.map { .mediaControl(HomeMediaControlCardConfig(entityId: $0)) },
                columnSpan: 2
            ))
        }

        return HomeDashboardViewConfig(
            path: HomeDashboardPath.mediaPlayers,
            title: strings.mediaPlayers,
            icon: HomeSummaryKind.mediaPlayers.icon,
            isSubview: true,
            content: .sections(sections),
            maxColumns: 2
        )
    }

    /// A subtitle per room, then that room's players.
    private static func areaCards(
        areaIds: [String],
        players: [String],
        registry: HomeRegistry
    ) -> [HomeDashboardCardConfig] {
        var cards: [HomeDashboardCardConfig] = []
        for areaId in areaIds {
            guard let area = registry.area(areaId) else {
                continue
            }
            let areaPlayers = players.filter { registry.context(of: $0).area?.id == areaId }
            guard !areaPlayers.isEmpty else {
                continue
            }
            cards.append(.heading(.init(
                id: "area:\(areaId)",
                heading: area.name,
                style: .subtitle,
                tapAction: .navigate(HomeDashboardPath.area(areaId))
            )))
            cards.append(contentsOf: areaPlayers.map { .mediaControl(HomeMediaControlCardConfig(entityId: $0)) })
        }
        return cards
    }
}
