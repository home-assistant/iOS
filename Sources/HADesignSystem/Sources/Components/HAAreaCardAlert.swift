#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI

/// A badge over an ``HAAreaCard``'s picture — "2 windows open", "motion detected".
///
/// Frontend counterpart: the `ha-tile-badge` entries `hui-area-card` builds from its alert
/// entities, rather than an element of its own.
public struct HAAreaCardAlert: Identifiable, Sendable {
    public let id: String
    public let icon: MaterialDesignIcons
    public let text: String
    public let color: Color

    public init(id: String, icon: MaterialDesignIcons, text: String, color: Color = .haWarningColor) {
        self.id = id
        self.icon = icon
        self.text = text
        self.color = color
    }
}

extension HAAreaCardAlert: FrontendComponent {
    public static var frontendComponentName: String { "hui-area-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
