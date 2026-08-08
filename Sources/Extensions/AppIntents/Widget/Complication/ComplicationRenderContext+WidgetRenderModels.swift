import HAWatchComplications
import Shared

/// Maps a resolved complication into the `HAWatchComplications` render models the lock-screen widgets
/// draw with.
///
/// Deliberately a field-for-field mirror of the in-app editor's `RectangularComplicationPreview` /
/// `CircularComplicationPreview` — the widgets render through the exact same content views, so if the
/// two mappings drift the lock screen stops matching the watch.
@available(iOS 17.0, *)
extension ComplicationRenderContext {
    var rectangularRenderModel: RectangularComplicationRenderModel {
        RectangularComplicationRenderModel(
            iconImage: iconImage,
            showsIcon: iconImage != nil,
            title: titleText,
            showsName: showsName,
            subtitle: subtitleText,
            showsSubtitle: showsSubtitle,
            fraction: showsGauge ? fraction : nil,
            minLabel: showsMin ? range.map { label($0.min) } : nil,
            maxLabel: showsMax ? range.map { label($0.max) } : nil,
            valueText: valueText,
            showsValue: showsValue,
            bottomText: bottomText,
            showsBottomText: showsBottomText,
            tint: tint,
            // nil lets the content view use `.primary`, which the lock screen renders white and the
            // Home Screen adapts — the editor preview can hardcode white only because it draws on a
            // black face.
            textColor: configuredTextColor,
            bottomTextColor: bottomTextColor
        )
    }

    var circularRenderModel: CircularComplicationRenderModel {
        CircularComplicationRenderModel(
            iconImage: iconImage,
            showsIcon: iconImage != nil,
            valueText: valueText,
            showsValue: showsValue,
            title: titleText,
            showsName: showsName,
            fraction: showsGauge ? fraction : nil,
            isCapacityGauge: gaugeStyle == .capacity,
            minLabel: showsMin ? range.map { label($0.min) } : nil,
            maxLabel: showsMax ? range.map { label($0.max) } : nil,
            tint: tint,
            textColor: configuredTextColor
        )
    }
}
