import Foundation

/// A legacy (ClockKit-era) `WatchComplication` resolved into the slots the modern WidgetKit renderer
/// draws: a title line, a value line, trailing bottom text, plus the gauge and icon.
///
/// The legacy model stores a free-form blob of per-template text areas, and ClockKit laid each
/// template out its own way. WidgetKit's four accessory families have one shared layout instead, so
/// the areas have to collapse onto it: they are read in the order the template declares them (which
/// is the order they appeared on the face), a gauge's end labels peel off to `minLabel` / `maxLabel`,
/// a row's second column folds onto the first, and the rest maps title → value → bottom text — or
/// value → title for the families that lead with their content (see `ContentLed`).
///
/// This is deliberately pure and lives in `Shared` — the watch turns it into a complication snapshot,
/// but the mapping itself is testable without a watch.
public struct LegacyComplicationRender: Equatable {
    /// The top line: the first text area, when the template has more than one.
    public let title: String
    /// The main content: the second text area, or the only one when that's all there is.
    public let value: String
    /// Everything past the second area (the columns and table templates), joined.
    public let bottomText: String
    /// Every area joined onto one line, for the single-line inline family.
    public let inlineText: String
    /// Hex color for `value`, or nil to use the face's default.
    public let textColor: String?
    /// Hex color for `bottomText`, or nil to fall back to `textColor`.
    public let bottomTextColor: String?
    /// Gauge/ring fill (0...1), or nil when the template has neither.
    public let fraction: Double?
    /// Hex tint for the gauge/ring.
    public let tint: String?
    /// Raw `WatchComplicationConfig.GaugeStyle`, or nil when there is no gauge.
    public let gaugeStyle: String?
    /// Material Design icon name, possibly in its server-side form (e.g. "mdi:home").
    public let iconName: String?
    /// Hex color for the icon.
    public let iconColor: String?
    /// The label for the low end of the gauge — the template's Leading area — or nil when it has none.
    public let minLabel: String?
    /// The label for the high end of the gauge — the template's Trailing area.
    public let maxLabel: String?
    /// The same areas mapped onto the families that lead with their content (see `ContentLed`).
    public let contentLed: ContentLed

    /// The corner and circular families' two text positions, which run the other way round to the rest.
    ///
    /// The rectangular and modular templates open with a `Header` — a label above the content — so
    /// their areas collapse onto title → value in declaration order. The corner and circular templates
    /// have no header: they lead with the content itself and caption it afterwards. Circular stacks its
    /// value above its name, and WidgetKit draws an `accessoryCorner` widget's own content on the
    /// *outside* of the curve with its `widgetLabel` on the *inside* — which is where ClockKit's
    /// `outerTextProvider` drew too. So for those two the first area is the value and the second is the
    /// title, the opposite way round from the header-led templates.
    public struct ContentLed: Equatable {
        /// The complication's own content: the template's first text area.
        public let value: String
        /// The caption: the template's second text area.
        public let title: String
        /// Hex color for `value`, or nil to use the face's default.
        public let textColor: String?
    }

    public init(complication: WatchComplication) {
        let data = complication.Data
        // Only the templates that ever drew an icon get one. The editor used to store an icon for the
        // rectangular "Standard Body" / "Text Gauge" and the Modular Large templates as well, but ClockKit
        // never rendered it for them, so honoring that stored icon now would add one those complications
        // never had — and shove their text over to make room for it.
        let icon = complication.Template.hasImage ? data["icon"] as? [String: String] : nil
        self.iconName = icon?["icon"]
        self.iconColor = icon?["icon_color"]

        let areas = Self.areas(from: complication)
        self.minLabel = areas.first { $0.area == .Leading }?.text
        self.maxLabel = areas.first { $0.area == .Trailing }?.text

        let lines = Self.lines(from: areas)
        // Fall back to the complication's own name only when it has nothing else to show, so an
        // image-only template (e.g. "Simple Image") stays image-only. Gated on the areas rather than
        // the body lines: a gauge template whose only filled areas are its end labels still has the
        // gauge to show, and would otherwise start captioning itself with the complication's name.
        let resolved: [(text: String, color: String?)] = areas.isEmpty && iconName == nil
            ? [(complication.displayName, nil)]
            : lines

        self.title = resolved.count > 1 ? resolved[0].text : ""
        self.value = resolved.count > 1 ? resolved[1].text : (resolved.first?.text ?? "")
        self.bottomText = resolved.dropFirst(2).map(\.text).joined(separator: " ")
        // Inline draws neither icon nor gauge, so its single line carries every area — the gauge's end
        // labels included, since they have nowhere else to go there. An image-only template has nothing
        // of the user's left to show and would otherwise render as the app's own name.
        let joined = areas.map(\.text).joined(separator: " ")
        self.inlineText = joined.isEmpty ? complication.displayName : joined

        // ClockKit only ever painted the picked colors on the full-color "graphic" families; it tinted
        // every other family itself. Honoring them everywhere would repaint complications that have
        // always rendered in the watch face's own tint.
        func graphicOnly(_ color: String?) -> String? {
            switch complication.Family {
            case .graphicBezel, .graphicCircular, .graphicCorner, .graphicRectangular: return color
            default: return nil
            }
        }
        self.textColor = graphicOnly(resolved.count > 1 ? resolved[1].color : resolved.first?.color)
        self.bottomTextColor = graphicOnly(resolved.dropFirst(2).first?.color)
        self.contentLed = ContentLed(
            value: resolved.first?.text ?? "",
            title: resolved.count > 1 ? resolved[1].text : "",
            textColor: graphicOnly(resolved.first?.color)
        )

        self.fraction = Self.fraction(from: data)
        self.tint = Self.tint(from: data)
        self.gaugeStyle = Self.gaugeStyle(from: data)
    }

    private typealias ResolvedArea = (area: ComplicationTextAreas, text: String, color: String?)

    /// The template's text areas in declaration order, each resolved to its server-rendered value
    /// (falling back to the configured text, which is what a non-template area stores) and paired with
    /// the area it came from and the color picked for it. Empty areas drop out.
    ///
    /// Walking `Template.textAreas` is what lets the areas no fixed key list mentioned — Outer, Inner,
    /// Leading, Trailing, Bottom and the third table row — render at all.
    private static func areas(from complication: WatchComplication) -> [ResolvedArea] {
        let configured = complication.Data["textAreas"] as? [String: [String: Any]] ?? [:]
        let rendered = renderedTextAreas(from: complication.Data)

        return complication.Template.textAreas.compactMap { area -> ResolvedArea? in
            let raw = configured[area.slug] ?? [:]
            let text = rendered[area.slug] ?? (raw["text"] as? String ?? "")
            guard !text.isEmpty else { return nil }
            return (area: area, text: text, color: raw["color"] as? String)
        }
    }

    /// The body lines the text slots are filled from: the areas that carry text, with a row's second
    /// column folded onto the first so the columns and table templates keep reading as rows.
    ///
    /// The gauge's end labels are not body text — they label the two ends of the gauge — so they are
    /// left out here and reach the face as `minLabel` / `maxLabel` instead.
    private static func lines(from areas: [ResolvedArea]) -> [(text: String, color: String?)] {
        var lines: [(text: String, color: String?)] = []
        var lastArea: ComplicationTextAreas?
        for entry in areas where !entry.area.isGaugeEndLabel {
            // Only fold a second column onto the line its own first column just emitted: when that
            // first column is empty it drops out above, and the second column would otherwise land on
            // the previous row's line.
            if let firstColumn = entry.area.firstColumnOfSameRow, firstColumn == lastArea,
               let previous = lines.popLast() {
                lines.append((previous.text + "  " + entry.text, previous.color))
            } else {
                lines.append((entry.text, entry.color))
            }
            lastArea = entry.area
        }
        return lines
    }

    private static func renderedTextAreas(from data: [String: Any]) -> [String: String] {
        guard let rendered = data["rendered"] as? [String: Any] else { return [:] }

        return rendered.reduce(into: [String: String]()) { result, item in
            guard item.key.hasPrefix("textArea,") else { return }

            let key = String(item.key.dropFirst("textArea,".count))
            result[key] = String(describing: item.value)
        }
    }

    private static func fraction(from data: [String: Any]) -> Double? {
        if let rendered = data["rendered"] as? [String: Any] {
            if let ringValue = rendered["ring"].flatMap(percentileNumber(from:)) {
                return ringValue
            } else if let gaugeValue = rendered["gauge"].flatMap(percentileNumber(from:)) {
                return gaugeValue
            }
        }

        if let ring = data["ring"] as? [String: String],
           let value = ring["ring_value"].flatMap(percentileNumber(from:)) {
            return value
        }

        if let gauge = data["gauge"] as? [String: String], let value = gauge["gauge"].flatMap(percentileNumber(from:)) {
            return value
        }

        return nil
    }

    private static func percentileNumber(from value: Any) -> Double? {
        WatchComplication.percentileNumber(from: value).map(Double.init)
    }

    private static func tint(from data: [String: Any]) -> String? {
        if let ring = data["ring"] as? [String: String], let color = ring["ring_color"] {
            return color
        }

        if let gauge = data["gauge"] as? [String: String], let color = gauge["gauge_color"] {
            return color
        }

        return nil
    }

    /// ClockKit's "closed" ring/gauge is the modern capacity ring, everything else the open arc. Ring
    /// wins over gauge, matching `fraction`.
    private static func gaugeStyle(from data: [String: Any]) -> String? {
        let type = (data["ring"] as? [String: String])?["ring_type"]
            ?? (data["gauge"] as? [String: String])?["gauge_type"]
        guard let type else { return nil }
        return type.lowercased() == "closed"
            ? WatchComplicationConfig.GaugeStyle.capacity.rawValue
            : WatchComplicationConfig.GaugeStyle.open.rawValue
    }
}
