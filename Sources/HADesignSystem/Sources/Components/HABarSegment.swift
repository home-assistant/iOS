#if !os(watchOS)
import SwiftUI

/// One slice of an ``HASegmentedBar``, mirroring the frontend's `Segment` interface.
///
/// `value` is a raw amount, not a percentage: the bar divides each segment by the total of the
/// visible ones, so callers pass whatever unit they measured in and never normalise themselves.
public struct HABarSegment: Identifiable {
    public let id: String
    public let value: Double
    public let color: Color
    /// Names the segment in the legend. A segment without one still takes up its share of the bar
    /// but is left out of the legend, as in the frontend.
    public let label: String?
    /// The amount written out — "12.4 kWh". Already formatted, because how a figure is rounded and
    /// what unit it carries are the app's business.
    ///
    /// `ha-segmented-bar`'s own legend does not show it; ``HADistributionCard``'s does, which is why
    /// it lives on the segment rather than on the card.
    public let formattedValue: String?

    public init(
        id: String,
        value: Double,
        color: Color,
        label: String? = nil,
        formattedValue: String? = nil
    ) {
        self.id = id
        self.value = value
        self.color = color
        self.label = label
        self.formattedValue = formattedValue
    }
}

extension HABarSegment: FrontendComponent {
    public static var frontendComponentName: String { "ha-segmented-bar" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
