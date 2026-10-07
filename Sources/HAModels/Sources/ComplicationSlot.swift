import Foundation

/// A position in a complication's layout that can be shown/hidden and filled with formula-driven
/// content. Which slots exist depends on the widget family — see `slots(for:)`; what a slot renders
/// comes from `WatchComplicationConfig.formula(for:family:)`.
public enum ComplicationSlot: String, Codable, CaseIterable, Identifiable {
    case icon
    case title
    case subtitle
    /// The value doubles as the gauge/progress-bar source where the family draws one.
    case value
    case bottomText

    public var id: String { rawValue }

    /// The slots a widget family offers, in their visual order.
    public static func slots(for family: WatchComplicationConfig.Family) -> [ComplicationSlot] {
        switch family {
        case .circular: return [.icon, .title, .value]
        case .rectangular: return [.icon, .title, .subtitle, .value, .bottomText]
        case .inline: return [.title]
        case .corner: return [.icon, .title, .value]
        }
    }
}
