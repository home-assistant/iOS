#if !os(watchOS)
import Foundation

/// The three shapes a gauge widget can take.
public enum WidgetGaugeType: String, CaseIterable, Sendable {
    /// An open arc with a value in the middle and labels at both ends.
    case normal
    /// An open arc captioned above the value instead of at its ends.
    case singleLabel
    /// A closed ring, for a value that fills something up.
    case capacity
}
#endif
