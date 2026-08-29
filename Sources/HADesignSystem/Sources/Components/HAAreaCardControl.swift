#if !os(watchOS)
import Foundation
import HAIconic

/// One switchable thing on an ``HAAreaCard`` — the room's lights, its fan, its blinds.
///
/// Frontend counterpart: an entry of `hui-area-card`'s controls row, rather than an element of its
/// own.
public struct HAAreaCardControl: Identifiable {
    public let id: String
    public let icon: MaterialDesignIcons
    /// Spoken by VoiceOver, since the button itself is only an icon.
    public let label: String
    public let isActive: Bool
    public let action: () -> Void

    public init(
        id: String,
        icon: MaterialDesignIcons,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.action = action
    }
}

extension HAAreaCardControl: FrontendComponent {
    public static var frontendComponentName: String { "hui-area-card" }
}

#endif
