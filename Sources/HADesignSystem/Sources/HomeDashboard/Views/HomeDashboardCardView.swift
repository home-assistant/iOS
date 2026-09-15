#if !os(watchOS)
import SwiftUI

/// Draws whichever card the strategy put here. One switch, so a new card type is one case in one
/// place rather than a branch in every section.
public struct HomeDashboardCardView: View {
    private let config: HomeDashboardCardConfig

    public init(config: HomeDashboardCardConfig) {
        self.config = config
    }

    public var body: some View {
        switch config {
        case let .heading(heading):
            HomeHeadingCardView(config: heading)
        case let .area(area):
            HomeAreaCardView(config: area)
        case let .tile(tile):
            HomeTileCardView(config: tile)
        case let .summary(summary):
            HomeSummaryCardView(config: summary)
        case let .pictureEntity(picture):
            HomePictureEntityCardView(config: picture)
        case let .emptyState(empty):
            HomeEmptyStateCardView(config: empty)
        case let .mediaControl(media):
            HomeMediaControlCardView(config: media)
        case let .entities(entities):
            HomeEntitiesCardView(config: entities)
        }
    }
}

#Preview {
    VStack {
        HomeDashboardCardView(config: .heading(HomeHeadingCardConfig(
            id: "lights",
            heading: "Lights",
            icon: "mdi:lamps"
        )))
        HomeDashboardCardView(config: .tile(HomeTileCardConfig(entityId: "light.kitchen_counter")))
        HomeDashboardCardView(config: .summary(HomeSummaryCardConfig(
            summary: .security,
            title: "Security",
            entityIds: ["lock.front_door"]
        )))
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .padding()
    .background(Color.haSecondaryBackground)
}

#endif
