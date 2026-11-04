#if !os(watchOS)
import Foundation
import HAIconic

/// One option in an ``HAButtonToggleGroup``, mirroring the frontend's `ToggleButton` type.
///
/// A button shows its icon when it has one and its label otherwise — the frontend keeps the label as
/// the button's title either way, so an icon-only group stays legible to VoiceOver.
public struct HAToggleButton: Identifiable {
    public let id: String
    public let label: String
    public let icon: MaterialDesignIcons?

    public init(id: String, label: String, icon: MaterialDesignIcons? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
    }
}

extension HAToggleButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-button-toggle-group" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
