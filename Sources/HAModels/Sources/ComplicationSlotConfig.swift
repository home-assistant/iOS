import Foundation

/// A user's customization of one complication slot for one widget family. Both fields are optional
/// on purpose: nil means "use the default", so untouched slots keep rendering exactly what the
/// pre-slot model rendered (see `WatchComplicationConfig.isSlotVisible` / `formula(for:family:)`).
public struct ComplicationSlotConfig: Codable, Equatable {
    /// nil = the family's default visibility for this slot.
    public var isVisible: Bool?
    /// nil = the slot's default content.
    public var formula: ComplicationFormula?
    /// Per-slot text color override (hex). nil = fall back to the family's text color. Only some slots
    /// honor it in rendering (e.g. the rectangular bottom text).
    public var color: String?

    public init(isVisible: Bool? = nil, formula: ComplicationFormula? = nil, color: String? = nil) {
        self.isVisible = isVisible
        self.formula = formula
        self.color = color
    }
}
