#if !os(watchOS)
import SwiftUI

private struct WidgetTileRowHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

public extension EnvironmentValues {
    /// How tall the row a tile is drawn in turns out to be, which is what the tile sizes its icon
    /// from: a row too short for the icon its size style draws gets a smaller one rather than one
    /// pressed against the card's edges. `nil` where nobody has measured a row.
    ///
    /// Carried in the environment rather than passed down, because the view that has to read it is
    /// not always the tile the grid rendered: a widget rebuilds the tile to draw a link in full
    /// colour on the versions of iOS that only tinted buttons, and that copy has to be sized the
    /// same as the one it replaces.
    var widgetTileRowHeight: CGFloat? {
        get { self[WidgetTileRowHeightEnvironmentKey.self] }
        set { self[WidgetTileRowHeightEnvironmentKey.self] = newValue }
    }
}
#endif
