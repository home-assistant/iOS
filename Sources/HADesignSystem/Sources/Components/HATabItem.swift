#if !os(watchOS)
import Foundation
import HAIconic

/// One tab in an ``HATabGroup``, mirroring the frontend's `ha-tab`.
public struct HATabItem: Identifiable {
    public let id: String
    public let name: String
    public let icon: MaterialDesignIcons?

    public init(id: String, name: String, icon: MaterialDesignIcons? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

extension HATabItem: FrontendComponent {
    public static var frontendComponentName: String { "ha-tab" }
}

#endif
