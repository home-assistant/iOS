import Foundation

/// A legacy (ClockKit-era) `WatchComplication` resolved into the slots the modern WidgetKit renderer
/// draws: a title line, a value line, trailing bottom text, plus the gauge and icon.
///
/// The legacy model stores a free-form blob of per-template text areas, and ClockKit laid each
/// template out its own way. WidgetKit's four accessory families have one shared layout instead, so
/// the areas have to collapse onto it: they are read in the order the template declares them (which
/// is the order they appeared on the face), a row's second column folds onto the first, and the
/// result maps title → value → bottom text.
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

    public init(complication: WatchComplication) {
        let data = complication.Data
        let icon = data["icon"] as? [String: String]
        self.iconName = icon?["icon"]
        self.iconColor = icon?["icon_color"]

        let lines = Self.lines(from: complication)
        // Fall back to the complication's own name only when it has nothing else to show, so an
        // image-only template (e.g. "Simple Image") stays image-only.
        let resolved: [(text: String, color: String?)] = lines.isEmpty && iconName == nil
            ? [(complication.displayName, nil)]
            : lines

        self.title = resolved.count > 1 ? resolved[0].text : ""
        self.value = resolved.count > 1 ? resolved[1].text : (resolved.first?.text ?? "")
        self.bottomText = resolved.dropFirst(2).map(\.text).joined(separator: " ")
        // Inline draws no icon, so an image-only template has nothing of the user's left to show
        // there and would otherwise render as the app's own name.
        let joined = resolved.map(\.text).joined(separator: " ")
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

        self.fraction = Self.fraction(from: data)
        self.tint = Self.tint(from: data)
        self.gaugeStyle = Self.gaugeStyle(from: data)
    }

    /// The template's text areas in declaration order, each resolved to its server-rendered value
    /// (falling back to the configured text, which is what a non-template area stores) and paired
    /// with the color picked for it. Empty areas drop out, and a row's second column folds onto the
    /// first so the columns and table templates keep reading as rows.
    ///
    /// Walking `Template.textAreas` is what lets the areas no fixed key list mentioned — Outer, Inner,
    /// Leading, Trailing, Bottom and the third table row — render at all.
    private static func lines(from complication: WatchComplication) -> [(text: String, color: String?)] {
        let configured = complication.Data["textAreas"] as? [String: [String: Any]] ?? [:]
        let rendered = renderedTextAreas(from: complication.Data)

        var lines: [(text: String, color: String?)] = []
        var lastArea: ComplicationTextAreas?
        for area in complication.Template.textAreas {
            let raw = configured[area.slug] ?? [:]
            let text = rendered[area.slug] ?? (raw["text"] as? String ?? "")
            guard !text.isEmpty else { continue }

            // Only fold a second column onto the line its own first column just emitted: when that
            // first column is empty it drops out above, and the second column would otherwise land on
            // the previous row's line.
            if let firstColumn = area.firstColumnOfSameRow, firstColumn == lastArea,
               let previous = lines.popLast() {
                lines.append((previous.text + "  " + text, previous.color))
            } else {
                lines.append((text, raw["color"] as? String))
            }
            lastArea = area
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
