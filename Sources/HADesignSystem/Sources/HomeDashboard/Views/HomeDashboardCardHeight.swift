#if !os(watchOS)
import SwiftUI

/// How tall a card is when the strategy asked for a number of rows rather than letting its contents
/// decide — the frontend's `grid_options.rows`.
///
/// The web dashboard's sections grid has rows of a fixed height with a fixed gap between them, so a
/// card that asks for two rows is the same height wherever it appears. That is what keeps every room
/// on the overview the same card, whether it has a temperature under its name or nothing at all.
public enum HomeDashboardCardHeight {
    /// `--row-height` in the frontend's grid, and the height a tile's icon-and-text row reserves.
    public static let row: CGFloat = 56
    /// `--row-gap`.
    public static let gap: CGFloat = DesignSystem.Spaces.one

    public static func height(rows: Int) -> CGFloat {
        CGFloat(rows) * row + CGFloat(rows - 1) * gap
    }

    /// What an area card, and the tile that stands in for one, are given.
    public static let areaCard = height(rows: 2)
}
#endif
