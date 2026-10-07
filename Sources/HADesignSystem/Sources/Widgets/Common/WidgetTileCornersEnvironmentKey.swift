#if !os(watchOS)
import SwiftUI

private struct WidgetTileCornersEnvironmentKey: EnvironmentKey {
    static let defaultValue: WidgetTileCorners = []
}

public extension EnvironmentValues {
    /// Which of a tile's corners sit in the widget's own corners.
    ///
    /// Carried in the environment rather than passed down, because the view that has to read it is
    /// not always the tile: a widget swaps a tile waiting on a confirmation for a
    /// ``WidgetTileConfirmationView``, and that stands in for the tile's card too.
    var widgetTileCorners: WidgetTileCorners {
        get { self[WidgetTileCornersEnvironmentKey.self] }
        set { self[WidgetTileCornersEnvironmentKey.self] = newValue }
    }
}
#endif
