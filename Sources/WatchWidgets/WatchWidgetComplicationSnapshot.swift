import SwiftUI
import UIKit
import WidgetKit

struct WatchWidgetComplicationSnapshot: Codable {
    static let placeholderID = "placeholder"
    static let assistID = "default-assist"

    /// Per-widget-family rendering values, keyed by `WatchComplicationConfig.Family.rawValue`
    /// ("circular"/"rectangular"/"inline"/"corner"). Absent for built-in/legacy complications.
    struct PerFamily: Codable {
        let fraction: Double?
        let tint: String?
        let showValue: Bool
        /// Whether to show the complication name (default true).
        var showName: Bool?
        /// Whether to show the icon (default true).
        var showIcon: Bool?
        /// Whether to show the gauge/progress-bar minimum / maximum labels (each default true).
        var showMin: Bool?
        var showMax: Bool?
        /// Raw gauge style ("open"/"capacity") for circular; nil defaults to open.
        var gaugeStyle: String?
        /// Pre-formatted gauge min/max labels for the open circular gauge.
        var minLabel: String?
        var maxLabel: String?
        /// Hex color for the value text; nil uses the default.
        var textColor: String?
        /// Resolved slot texts (slot/formula model). All optional so payloads written before slots
        /// existed still decode — the accessors below then fall back to the top-level
        /// `title`/`subtitle`. Mutable so the widget's live self-fetch can update them in place.
        var title: String?
        var subtitle: String?
        var value: String?
        var bottomText: String?
        /// Visibility of the slots that have no legacy flag (both default hidden).
        var showSubtitle: Bool?
        var showBottomText: Bool?
    }

    let id: String?
    let family: String
    /// Mutable so the widget's live self-fetch can update the on-face value in place.
    var title: String
    let subtitle: String
    /// Mutable so the widget's live self-fetch can update the inline value in place.
    var inlineText: String
    let fraction: Double?
    let tint: String?
    let iconData: Data?
    var perFamily: [String: PerFamily]?
    /// The name shown in the complication picker (the value goes in `title` for on-face rendering).
    /// Optional so older payloads without it still decode.
    let menuName: String?
    /// Whether the complication is shown while the display is dimmed (default true).
    var showWhenInactive: Bool?

    static var placeholder: Self {
        .init(
            id: placeholderID,
            family: "",
            title: WatchWidgetConstants.appName,
            subtitle: WatchWidgetConstants.placeholderSubtitle,
            inlineText: WatchWidgetConstants.appName,
            fraction: nil,
            tint: nil,
            iconData: nil,
            perFamily: nil,
            menuName: WatchWidgetConstants.appName
        )
    }

    static var assist: Self {
        .init(
            id: assistID,
            family: "",
            title: "Assist",
            subtitle: WatchWidgetConstants.appName,
            inlineText: "Assist",
            fraction: nil,
            tint: nil,
            iconData: nil,
            perFamily: nil,
            menuName: "Assist"
        )
    }

    private static func familyKey(for widgetFamily: WidgetFamily) -> String? {
        switch widgetFamily {
        case .accessoryCircular: return "circular"
        case .accessoryRectangular: return "rectangular"
        case .accessoryInline: return "inline"
        case .accessoryCorner: return "corner"
        default: return nil
        }
    }

    func options(for widgetFamily: WidgetFamily) -> PerFamily? {
        Self.familyKey(for: widgetFamily).flatMap { perFamily?[$0] }
    }

    /// The gauge fraction for a given family (per-family override, else the top-level value).
    func fraction(for widgetFamily: WidgetFamily) -> Double? {
        options(for: widgetFamily)?.fraction ?? fraction
    }

    /// The tint color for a given family.
    func tintColor(for widgetFamily: WidgetFamily) -> Color {
        Color(hex: options(for: widgetFamily)?.tint ?? tint) ?? .accentColor
    }

    /// The value/text color for a given family, or nil to use the default.
    func textColor(for widgetFamily: WidgetFamily) -> Color? {
        options(for: widgetFamily)?.textColor.flatMap { Color(hex: $0) }
    }

    /// Whether to show the state value as text for a given family (default true).
    func showsValue(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showValue ?? true
    }

    /// Whether to show the complication name for a given family (default true).
    func showsName(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showName ?? true
    }

    /// Whether to show the icon for a given family (default true).
    func showsIcon(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showIcon ?? true
    }

    /// Whether to show the gauge/progress-bar minimum label for a given family (default true).
    func showsMin(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showMin ?? true
    }

    /// Whether to show the gauge/progress-bar maximum label for a given family (default true).
    func showsMax(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showMax ?? true
    }

    /// Whether the complication should render while the display is dimmed (default true).
    var showsWhenInactive: Bool { showWhenInactive ?? true }

    // MARK: - Slot texts

    // The top-level fields predate slots and are confusingly inverted (`title` carries the value,
    // `subtitle` the name); they remain the fallback for payloads written before slots existed.

    /// The resolved title-slot text for a family (the complication's name unless customized).
    func titleText(for widgetFamily: WidgetFamily) -> String {
        options(for: widgetFamily)?.title ?? subtitle
    }

    /// The resolved value-slot text for a family (the formatted state unless customized).
    func valueText(for widgetFamily: WidgetFamily) -> String {
        options(for: widgetFamily)?.value ?? title
    }

    func subtitleText(for widgetFamily: WidgetFamily) -> String {
        options(for: widgetFamily)?.subtitle ?? ""
    }

    func bottomTextValue(for widgetFamily: WidgetFamily) -> String {
        options(for: widgetFamily)?.bottomText ?? ""
    }

    /// Subtitle / bottom text have no legacy flag: hidden unless the slot payload shows them.
    func showsSubtitle(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showSubtitle ?? false
    }

    func showsBottomText(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.showBottomText ?? false
    }

    /// Whether the circular gauge should be drawn as a full capacity ring (vs the open arc).
    func isCapacityGauge(for widgetFamily: WidgetFamily) -> Bool {
        options(for: widgetFamily)?.gaugeStyle == "capacity"
    }

    /// Gauge min/max labels (open circular gauge only), when a range is configured.
    func gaugeLabels(for widgetFamily: WidgetFamily) -> (min: String, max: String)? {
        guard let options = options(for: widgetFamily),
              let minLabel = options.minLabel, let maxLabel = options.maxLabel else { return nil }
        return (minLabel, maxLabel)
    }

    var recommendationID: String {
        id ?? [family, title, subtitle].joined(separator: ":")
    }

    var recommendationTitle: String {
        // The picker should show the complication's name, not its live value.
        if let menuName, !menuName.isEmpty { return menuName }
        return title.isEmpty ? WatchWidgetConstants.appName : title
    }

    /// A static stand-in for the complication picker (`context.isPreview`): identity only — name,
    /// icon, gauge shape and colors — with the value slot neutralized. The picker preview must
    /// render instantly from whatever is cached and must not present a possibly-stale value as
    /// current. Built-ins (placeholder/Assist) already carry static text and pass through as-is.
    var previewVariant: Self {
        guard !isBuiltIn else { return self }
        var preview = self
        preview.title = WatchWidgetConstants.previewValueText
        // Inline renders a single line of text: the name identifies the complication better than
        // a bare "--".
        preview.inlineText = recommendationTitle
        preview.perFamily = perFamily?.mapValues { options in
            var options = options
            if options.value != nil { options.value = WatchWidgetConstants.previewValueText }
            return options
        }
        if var inline = preview.perFamily?["inline"], inline.title != nil {
            inline.title = recommendationTitle
            preview.perFamily?["inline"] = inline
        }
        return preview
    }

    var widgetURL: URL? {
        recommendationID == Self.assistID ? WatchWidgetConstants.DeepLink.assistURL : nil
    }

    var tintColor: Color {
        Color(hex: tint) ?? .accentColor
    }

    private var isBuiltIn: Bool {
        [Self.placeholderID, Self.assistID].contains(recommendationID)
    }

    var isAssist: Bool {
        recommendationID == Self.assistID
    }

    /// The custom icon carried by a user-configured complication. Built-in complications (placeholder /
    /// Assist) intentionally ignore any carried icon and use a clean SF Symbol instead: the Home
    /// Assistant logo is a solid, full-bleed shape that collapses into an unreadable blob when the watch
    /// renders a complication as a monochrome template, whereas an SF Symbol renders as a crisp glyph.
    var iconImage: Image? {
        guard !isBuiltIn, let iconData, let image = UIImage(data: iconData) else { return nil }
        return Image(uiImage: image).renderingMode(.template)
    }

    // Asset-catalog image used when there is no custom template icon: the Assist symbol for the Assist
    // complication, otherwise the Home Assistant logo. Both are template-rendering assets in the
    // widget bundle so they tint cleanly on the watch face.
    var fallbackImageName: String {
        switch recommendationID {
        case Self.assistID:
            WatchWidgetConstants.assistIconAssetName
        default:
            WatchWidgetConstants.logoAssetName
        }
    }
}

#if DEBUG
extension WatchWidgetComplicationSnapshot {
    /// Sample used by the SwiftUI previews of the per-family complication views.
    static func previewSample(
        title: String = "100%",
        subtitle: String = "Battery",
        fraction: Double? = 0.68,
        gaugeStyle: String = "open",
        showValue: Bool = true,
        showName: Bool = true,
        showIcon: Bool = true,
        includeIcon: Bool = false
    ) -> Self {
        let options = PerFamily(
            fraction: fraction,
            tint: "#34C759FF",
            showValue: showValue,
            showName: showName,
            showIcon: showIcon,
            showMin: true,
            showMax: true,
            gaugeStyle: gaugeStyle,
            minLabel: "0",
            maxLabel: "100",
            textColor: nil
        )
        return .init(
            id: "preview",
            family: "",
            title: title,
            subtitle: subtitle,
            inlineText: "\(subtitle) \(title)",
            fraction: fraction,
            tint: "#34C759FF",
            iconData: includeIcon ? UIImage(systemName: "lightbulb.fill")?.pngData() : nil,
            perFamily: ["circular": options, "rectangular": options, "inline": options, "corner": options],
            menuName: subtitle
        )
    }

    static func previewSampleValueOnly(
        title: String = "100%",
        fraction: Double? = 0.68,
        gaugeStyle: String = "open"
    ) -> Self {
        let options = PerFamily(
            fraction: fraction,
            tint: "#34C759FF",
            showValue: true,
            showName: false,
            showIcon: false,
            showMin: true,
            showMax: true,
            gaugeStyle: gaugeStyle,
            minLabel: "0",
            maxLabel: "100",
            textColor: nil
        )
        return .init(
            id: "preview",
            family: "",
            title: title,
            subtitle: "Battery",
            inlineText: "Battery \(title)",
            fraction: fraction,
            tint: "#34C759FF",
            iconData: nil,
            perFamily: ["circular": options, "rectangular": options, "inline": options, "corner": options],
            menuName: "Battery"
        )
    }
}
#endif
