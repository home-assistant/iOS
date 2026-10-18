#if !os(watchOS)
import Foundation

/// How full a widget family is allowed to be packed with tiles.
public enum WidgetTileCapacity: String, CaseIterable, Sendable {
    /// Every tile the family physically fits, compressing the cards away once they stop fitting.
    /// What a widget gets unless it asks otherwise.
    case packed
    /// The most tiles that still read as entity tiles: every one keeps its padding, border and card.
    case tile
}
#endif
