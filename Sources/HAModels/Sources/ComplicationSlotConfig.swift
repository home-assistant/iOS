import Foundation

/// A user's customization of one complication slot for one widget family. Both fields are optional
/// on purpose: nil means "use the default", so untouched slots keep rendering exactly what the
/// pre-slot model rendered (see `WatchComplicationConfig.isSlotVisible` / `formula(for:family:)`).
public struct ComplicationSlotConfig: Codable, Equatable {
    /// nil = the family's default visibility for this slot.
    public var isVisible: Bool?
    /// nil = the slot's default content.
    public var formula: ComplicationFormula?

    public init(isVisible: Bool? = nil, formula: ComplicationFormula? = nil) {
        self.isVisible = isVisible
        self.formula = formula
    }
}
