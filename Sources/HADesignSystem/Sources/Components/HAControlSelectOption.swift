#if !os(watchOS)
import Foundation
import HAIconic

/// One choice in an ``HAControlSelect``, mirroring the frontend's `ControlSelectOption`.
public struct HAControlSelectOption: Identifiable {
    public let id: String
    public let label: String
    public let icon: MaterialDesignIcons?
    public let isDisabled: Bool

    public init(id: String, label: String, icon: MaterialDesignIcons? = nil, isDisabled: Bool = false) {
        self.id = id
        self.label = label
        self.icon = icon
        self.isDisabled = isDisabled
    }
}

extension HAControlSelectOption: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-select" }
}

#endif
