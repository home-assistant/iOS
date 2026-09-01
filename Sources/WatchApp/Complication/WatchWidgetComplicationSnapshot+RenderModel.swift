import HAWatchComplications
import Shared
import SwiftUI
import UIKit

extension WatchWidgetComplicationSnapshot {
    /// Resolves this snapshot into the shared rectangular render model, so a complication shown in
    /// the watch's item list is drawn by the very same `RectangularComplicationContentView` the face
    /// uses. Deliberately a field-for-field mirror of the widget extension's
    /// `RectangularComplicationView.renderModel(_:)` — if the two drift, the in-app row stops being a
    /// faithful preview of the complication.
    ///
    /// `nil` for the built-in placeholder and Assist snapshots, which carry no `perFamily` payload and
    /// have no rectangular layout to reproduce. Legacy (server-rendered) complications do carry one —
    /// see `init(complication:)` — so they draw here through the same layout as everything else.
    var rectangularRenderModel: RectangularComplicationRenderModel? {
        guard let options = perFamily?[WatchComplicationConfig.Family.rectangular.rawValue] else {
            return nil
        }
        let gaugeLabels = Self.gaugeLabels(from: options)
        return RectangularComplicationRenderModel(
            iconImage: iconImage,
            showsIcon: options.showIcon ?? true,
            title: options.title ?? subtitle,
            showsName: options.showName ?? true,
            subtitle: options.subtitle ?? "",
            showsSubtitle: options.showSubtitle ?? false,
            fraction: options.fraction ?? fraction,
            minLabel: (options.showMin ?? true) ? gaugeLabels?.min : nil,
            maxLabel: (options.showMax ?? true) ? gaugeLabels?.max : nil,
            valueText: options.value ?? title,
            showsValue: options.showValue,
            bottomText: options.bottomText ?? "",
            showsBottomText: options.showBottomText ?? false,
            tint: Self.color(hex: options.tint ?? tint) ?? .complicationDefaultTint,
            textColor: Self.color(hex: options.textColor),
            bottomTextColor: Self.color(hex: options.bottomTextColor)
        )
    }

    /// The rasterized icon the snapshot carries, as a template image so it tints with the row.
    private var iconImage: Image? {
        guard let iconData, let image = UIImage(data: iconData) else { return nil }
        return Image(uiImage: image).renderingMode(.template)
    }

    /// Both edges or neither: a gauge with only one end labelled reads as a mislabelled scale, which
    /// is why the widget's `gaugeLabels(for:)` is all-or-nothing too.
    private static func gaugeLabels(from options: PerFamily) -> (min: String, max: String)? {
        guard let minLabel = options.minLabel, let maxLabel = options.maxLabel else { return nil }
        return (minLabel, maxLabel)
    }

    /// Failable on purpose — `nil` means "no override, use the view's default". The `Shared`
    /// `Color(hex:)` can't express that: it substitutes the brand color and logs an error.
    private static func color(hex: String?) -> Color? {
        guard let hex else { return nil }
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6 || sanitized.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&value) else { return nil }

        let includesAlpha = sanitized.count == 8
        let red = Double((value >> (includesAlpha ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (includesAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (includesAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = includesAlpha ? Double(value & 0xFF) / 255 : 1
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
