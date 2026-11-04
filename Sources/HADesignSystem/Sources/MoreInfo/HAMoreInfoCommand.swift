#if !os(watchOS)
import HAIconic
import SwiftUI

/// One command a more-info dialog offers as a button: start, stop, return to dock, locate.
///
/// Frontend counterpart: the `ha-control-button`s each dialog renders from the entity's supported
/// features. A model, so the dialogs that share a row of them (vacuum, lawn mower, media player)
/// lay it out once.
public struct HAMoreInfoCommand: Identifiable {
    public let id: String
    public let icon: MaterialDesignIcons
    public let label: String
    public let isDisabled: Bool
    public let action: () -> Void

    /// - Parameter label: The accessibility name; the button shows only the glyph.
    public init(
        id: String,
        icon: MaterialDesignIcons,
        label: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.isDisabled = isDisabled
        self.action = action
    }
}
#endif
