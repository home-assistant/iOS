import SwiftUI

/// The resolved, target-agnostic rendering inputs for the corner complication.
///
/// Unlike the other families, the real watch corner view renders through the native
/// `widgetCurvesContent()` / `widgetLabel` APIs (which only work inside a widget host), so it can't be
/// unified with the preview into a single rendering. This model is the shared seam that keeps both
/// sides resolving the same text / gauge; `CornerComplicationContentView` renders the iPhone-side
/// (and snapshot) approximation of the on-face layout.
public struct CornerComplicationRenderModel {
    public var iconImage: Image?
    public var title: String
    public var showsName: Bool
    public var valueText: String
    public var showsValue: Bool
    /// Gauge fill (0...1), or nil when there's no gauge.
    public var fraction: Double?
    public var tint: Color
    /// nil resolves to `.primary` (white on the black watch face).
    public var textColor: Color?
    /// Whether the corner's own text rides the outer curve (the modern layout) or sits flat and large in
    /// the corner tip, the way ClockKit drew a Graphic Corner's outer text. Legacy complications whose
    /// template drew its text flat opt out of the curve.
    public var curvesText: Bool

    public init(
        iconImage: Image? = nil,
        title: String = "",
        showsName: Bool = false,
        valueText: String = "",
        showsValue: Bool = false,
        fraction: Double? = nil,
        tint: Color = .complicationDefaultTint,
        textColor: Color? = nil,
        curvesText: Bool = true
    ) {
        self.iconImage = iconImage
        self.title = title
        self.showsName = showsName
        self.valueText = valueText
        self.showsValue = showsValue
        self.fraction = fraction
        self.tint = tint
        self.textColor = textColor
        self.curvesText = curvesText
    }
}
