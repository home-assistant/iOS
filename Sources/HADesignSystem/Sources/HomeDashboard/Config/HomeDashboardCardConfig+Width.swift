import Foundation

public extension HomeDashboardCardConfig {
    /// The same card taking a whole row. The overview emits its summaries twice — half-width in the
    /// flow of a phone, full-width in the sidebar of a wide window — and this is the difference.
    var fullWidth: HomeDashboardCardConfig {
        switch self {
        case let .tile(config):
            .tile(HomeTileCardConfig(
                entityId: config.entityId,
                name: config.name,
                icon: config.icon,
                feature: config.feature,
                isVertical: config.isVertical,
                hidesState: config.hidesState,
                showsAreaName: config.showsAreaName,
                tapAction: config.tapAction,
                columns: 12
            ))
        case let .summary(config):
            .summary(HomeSummaryCardConfig(
                summary: config.summary,
                title: config.title,
                entityIds: config.entityIds,
                tapAction: config.tapAction,
                columns: 12
            ))
        case .heading, .area, .pictureEntity, .emptyState:
            self
        }
    }
}
