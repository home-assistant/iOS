#if !os(watchOS)
import HAIconic
import SwiftUI

/// An entity as a card draws it: an icon, a colour, two lines of text and whether it is doing
/// anything. Everything a tile needs and nothing about where the values came from.
public struct HomeEntityPresentation: Equatable {
    public let icon: MaterialDesignIcons
    /// The colour the icon takes while the entity is active.
    public let color: Color
    /// The entity's name.
    public let primary: String
    /// Its state, written the way a person reads it — "Playing", "21.4 °C".
    public let secondary: String?
    /// Whether the entity is on, open, playing: what lets the colour through.
    public let isActive: Bool
    public let isUnavailable: Bool

    public init(
        icon: MaterialDesignIcons,
        color: Color,
        primary: String,
        secondary: String? = nil,
        isActive: Bool = false,
        isUnavailable: Bool = false
    ) {
        self.icon = icon
        self.color = color
        self.primary = primary
        self.secondary = secondary
        self.isActive = isActive
        self.isUnavailable = isUnavailable
    }
}
#endif
