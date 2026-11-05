#if !os(watchOS)
import SwiftUI

/// The two independently tappable regions of a widget tile.
///
/// Mirrors the frontend's tile card: the icon carries the entity's control, and everything else
/// opens the entity. The design system draws both halves and knows nothing about what either one
/// does, so the widget hands back the controls that wrap them — the same arrangement as
/// ``WidgetTileGridView``'s `tileContent`, one level further in.
///
/// The two never overlap. WidgetKit picks a tap's owner from the frames it archived for its links
/// and intent controls, not from SwiftUI's view order, so a control laid over another would lose
/// its taps to the one underneath. `body` may be applied more than once, to each part of the tile
/// that is not the icon.
///
/// A tile whose icon and body would run the same thing has no reason to be split: leave the regions
/// off and let the whole tile be one control.
public struct WidgetTileRegions {
    /// Wraps a rendered region in the control that runs it.
    public typealias Region = (AnyView) -> AnyView

    /// Wraps the tile's icon.
    public let icon: Region
    /// Wraps the rest of the tile: everything that is not the icon, in one or more pieces.
    public let body: Region

    public init(icon: @escaping Region, body: @escaping Region) {
        self.icon = icon
        self.body = body
    }
}
#endif
