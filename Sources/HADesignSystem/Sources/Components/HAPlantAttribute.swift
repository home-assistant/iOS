#if !os(watchOS)
import Foundation
import HAIconic

/// One reading on an ``HAPlantStatusCard`` — moisture, battery, temperature and so on.
///
/// Frontend counterpart: an entry of `hui-plant-status-card`'s `attributes` list, rather than an
/// element of its own.
public struct HAPlantAttribute: Identifiable, Sendable {
    public let id: String
    public let icon: MaterialDesignIcons
    public let value: String
    public let unit: String?
    /// Whether this reading is one the plant is currently unhappy about — the frontend's `problem`
    /// class, which is what turns the row red.
    public let isProblem: Bool

    public init(
        id: String,
        icon: MaterialDesignIcons,
        value: String,
        unit: String? = nil,
        isProblem: Bool = false
    ) {
        self.id = id
        self.icon = icon
        self.value = value
        self.unit = unit
        self.isProblem = isProblem
    }
}

extension HAPlantAttribute: FrontendComponent {
    public static var frontendComponentName: String { "hui-plant-status-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
