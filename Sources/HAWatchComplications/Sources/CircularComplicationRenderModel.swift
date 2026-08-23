import SwiftUI

/// The resolved, target-agnostic rendering inputs for the circular complication.
///
/// Both the on-watch `WatchWidgetComplicationSnapshot` (in the WatchWidgets extension) and the shared
/// `ComplicationRenderContext` (the in-app editor preview and the iPhone lock-screen widgets) map their
/// own data into this one struct, so a single `CircularComplicationContentView` renders identically
/// everywhere the complication appears.
public struct CircularComplicationRenderModel {
    public var iconImage: Image?
    public var showsIcon: Bool
    public var valueText: String
    public var showsValue: Bool
    public var title: String
    public var showsName: Bool
    /// Gauge fill (0...1), or nil to render only the center content (no gauge).
    public var fraction: Double?
    /// A full capacity ring instead of an open arc.
    public var isCapacityGauge: Bool
    /// Already gated by the min/max visibility toggles by the caller (nil hides the label).
    public var minLabel: String?
    public var maxLabel: String?
    public var tint: Color
    /// nil resolves to `.primary` (white on the black watch face).
    public var textColor: Color?

    public init(
        iconImage: Image? = nil,
        showsIcon: Bool = false,
        valueText: String = "",
        showsValue: Bool = false,
        title: String = "",
        showsName: Bool = false,
        fraction: Double? = nil,
        isCapacityGauge: Bool = false,
        minLabel: String? = nil,
        maxLabel: String? = nil,
        tint: Color = .complicationDefaultTint,
        textColor: Color? = nil
    ) {
        self.iconImage = iconImage
        self.showsIcon = showsIcon
        self.valueText = valueText
        self.showsValue = showsValue
        self.title = title
        self.showsName = showsName
        self.fraction = fraction
        self.isCapacityGauge = isCapacityGauge
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.tint = tint
        self.textColor = textColor
    }

    /// Whether the center renders only the state value (no icon and no name), so it can use the full
    /// inner circle and a larger font.
    public var isValueOnly: Bool {
        let hasIcon = showsIcon && iconImage != nil
        let hasName = showsName && !title.isEmpty
        return !hasIcon && !hasName
    }

    /// Whether the face leads with a large centered icon and renders the value in the open gauge's
    /// bottom label instead of stacking the two in the middle.
    ///
    /// That bottom slot is occupied by the min/max labels when they're shown and doesn't exist on the
    /// capacity ring, so this is exactly the open-gauge-without-min/max case: with the slot free, the
    /// value reads better underneath and the icon gets the whole inner circle rather than sharing it.
    public var isIconLedWithBottomValue: Bool {
        guard fraction != nil, !isCapacityGauge, minLabel == nil, maxLabel == nil else { return false }
        return showsIcon && iconImage != nil && showsValue && !valueText.isEmpty
    }
}
