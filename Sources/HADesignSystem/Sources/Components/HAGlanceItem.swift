#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI

/// One cell of an ``HAGlanceCard``, mirroring the frontend's `GlanceConfigEntity`.
public struct HAGlanceItem: Identifiable {
    public let id: String
    public let name: String
    public let icon: MaterialDesignIcons?
    public let color: Color
    public let state: String?

    public init(
        id: String,
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haDisabled,
        state: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.state = state
    }
}

extension HAGlanceItem: FrontendComponent {
    public static var frontendComponentName: String { "hui-glance-card" }
}

#endif
