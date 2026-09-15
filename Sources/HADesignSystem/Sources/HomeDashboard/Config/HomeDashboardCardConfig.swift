import Foundation

/// One card in a section. The cases are exactly the card types the home strategy emits — anything
/// the web dashboard can show but this strategy never asks for is deliberately absent.
public enum HomeDashboardCardConfig: Identifiable, Equatable, Sendable {
    case heading(HomeHeadingCardConfig)
    case area(HomeAreaCardConfig)
    case tile(HomeTileCardConfig)
    case summary(HomeSummaryCardConfig)
    /// A camera, which the strategy shows as its picture rather than as a tile.
    case pictureEntity(HomePictureEntityCardConfig)
    case emptyState(HomeEmptyStateCardConfig)

    public var id: String {
        switch self {
        case let .heading(config): "heading:\(config.id)"
        case let .area(config): "area:\(config.areaId)"
        case let .tile(config): "tile:\(config.entityId)"
        case let .summary(config): "summary:\(config.summary.rawValue)"
        case let .pictureEntity(config): "picture:\(config.entityId)"
        case let .emptyState(config): "empty:\(config.title)"
        }
    }

    /// How many of a section's twelve columns the card takes. A heading and an empty state take the
    /// whole row; an area card takes a third, which is what puts three rooms side by side.
    public var columns: Int {
        switch self {
        case .heading, .emptyState: 12
        case .area: 4
        case let .tile(config): config.columns
        case let .summary(config): config.columns
        case .pictureEntity: 6
        }
    }

    /// The entity a card is about, when it is about one. Used to decide which cards a state change
    /// has to redraw.
    public var entityId: String? {
        switch self {
        case let .tile(config): config.entityId
        case let .pictureEntity(config): config.entityId
        case .heading, .area, .summary, .emptyState: nil
        }
    }
}
