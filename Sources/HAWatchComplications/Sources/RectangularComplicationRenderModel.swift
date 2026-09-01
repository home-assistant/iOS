import SwiftUI

/// The resolved, target-agnostic rendering inputs for the rectangular complication.
///
/// Both the on-watch `WatchWidgetComplicationSnapshot` (in the WatchWidgets extension) and the shared
/// `ComplicationRenderContext` (the in-app editor preview and the iPhone lock-screen widgets) map their
/// own data into this one struct, so a single `RectangularComplicationContentView` renders identically
/// everywhere the complication appears.
/// This is the seam that guarantees the preview can't drift from the watch.
public struct RectangularComplicationRenderModel {
    public var iconImage: Image?
    public var showsIcon: Bool
    public var title: String
    public var showsName: Bool
    public var subtitle: String
    public var showsSubtitle: Bool
    /// Gauge fill (0...1), or nil to render the value as plain text instead of a progress bar.
    public var fraction: Double?
    /// Already gated by the min/max visibility toggles by the caller (nil hides the label).
    public var minLabel: String?
    public var maxLabel: String?
    public var valueText: String
    public var showsValue: Bool
    public var bottomText: String
    public var showsBottomText: Bool
    public var tint: Color
    /// nil resolves to `.primary` (white on the black watch face).
    public var textColor: Color?
    /// Per-slot color override for the bottom text; nil falls back to `textColor`.
    public var bottomTextColor: Color?

    public init(
        iconImage: Image? = nil,
        showsIcon: Bool = false,
        title: String = "",
        showsName: Bool = false,
        subtitle: String = "",
        showsSubtitle: Bool = false,
        fraction: Double? = nil,
        minLabel: String? = nil,
        maxLabel: String? = nil,
        valueText: String = "",
        showsValue: Bool = false,
        bottomText: String = "",
        showsBottomText: Bool = false,
        tint: Color = .complicationDefaultTint,
        textColor: Color? = nil,
        bottomTextColor: Color? = nil
    ) {
        self.iconImage = iconImage
        self.showsIcon = showsIcon
        self.title = title
        self.showsName = showsName
        self.subtitle = subtitle
        self.showsSubtitle = showsSubtitle
        self.fraction = fraction
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.valueText = valueText
        self.showsValue = showsValue
        self.bottomText = bottomText
        self.showsBottomText = showsBottomText
        self.tint = tint
        self.textColor = textColor
        self.bottomTextColor = bottomTextColor
    }
}
