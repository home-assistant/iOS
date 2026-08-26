#if !os(watchOS)
import Foundation

/// Which tile layout a grid draws: an action, or a reading.
public enum WidgetTileKind: String, CaseIterable, Sendable {
    /// Icon first, then the label — what a tile the user taps looks like.
    case button
    /// Label first and the icon pushed to the trailing edge, so the value leads.
    case sensor
}
#endif
