#if !os(watchOS)
import Foundation

/// The corners of a tile that sit in one of the widget's own corners.
///
/// Only those corners round wider, to keep from reading as pinched inside the widget's own. A corner
/// merely lying along one of the widget's edges is not one of them: widening those would round the
/// seam where two rows meet. ``WidgetTileGridView`` is the only thing that knows which tile is
/// where, so it is what sets this — see ``EnvironmentValues/widgetTileCorners``.
public struct WidgetTileCorners: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let topLeading = WidgetTileCorners(rawValue: 1 << 0)
    public static let topTrailing = WidgetTileCorners(rawValue: 1 << 1)
    public static let bottomLeading = WidgetTileCorners(rawValue: 1 << 2)
    public static let bottomTrailing = WidgetTileCorners(rawValue: 1 << 3)
}
#endif
