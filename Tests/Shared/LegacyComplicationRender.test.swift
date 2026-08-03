import Foundation
@testable import Shared
import Testing

/// Legacy (ClockKit-era) complications are rendered by the modern WidgetKit views now, which means
/// their per-template text areas have to collapse onto the shared title / value / bottom-text layout.
/// These pin that mapping down — regressions here show up as a blank or logo-only watch face.
struct LegacyComplicationRenderTests {
    private func complication(
        family: ComplicationGroupMember,
        template: ComplicationTemplate,
        textAreas: [String: (text: String, color: String)] = [:],
        rendered: [String: Any] = [:],
        extra: [String: Any] = [:]
    ) -> WatchComplication {
        var complication = WatchComplication(family: family, template: template, name: "Rain")
        var areas: [String: [String: Any]] = [:]
        for (slug, area) in textAreas {
            areas[slug] = ["text": area.text, "color": area.color]
        }
        var data: [String: Any] = extra
        data["textAreas"] = areas
        if !rendered.isEmpty {
            data["rendered"] = rendered
        }
        complication.Data = data
        return complication
    }

    // MARK: - Text areas

    /// The Graphic Corner "Text Image" complication behind the long-standing rain-sparkline recipe:
    /// an icon in the corner and a single Center text area riding the arc.
    @Test func singleTextAreaBecomesTheValue() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerTextImage,
            textAreas: ["Center": ("▁▂▃▄▅▆▇█", "#00FF00FF")],
            extra: ["icon": ["icon": "weather-pouring", "icon_color": "#FFFFFFFF"]]
        ))

        #expect(render.value == "▁▂▃▄▅▆▇█")
        #expect(render.title.isEmpty)
        #expect(render.bottomText.isEmpty)
        #expect(render.iconName == "weather-pouring")
    }

    @Test func firstAreaLabelsTheSecond() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicRectangular,
            template: .GraphicRectangularStandardBody,
            textAreas: [
                "Header": ("Rain", "#FFFFFFFF"),
                "Body1": ("▁▂▃", "#00FF00FF"),
                "Body2": ("in 45m", "#FF0000FF"),
            ]
        ))

        #expect(render.title == "Rain")
        #expect(render.value == "▁▂▃")
        #expect(render.bottomText == "in 45m")
        #expect(render.inlineText == "Rain ▁▂▃ in 45m")
    }

    /// Areas are read in the template's own order, not in whatever order the blob happens to
    /// enumerate — the templates put the label first for a reason.
    @Test func areasFollowTemplateOrder() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerStackText,
            textAreas: ["Inner": ("inner", "#FFFFFFFF"), "Outer": ("outer", "#FFFFFFFF")]
        ))

        // GraphicCornerStackText declares [.Outer, .Inner].
        #expect(render.title == "outer")
        #expect(render.value == "inner")
    }

    /// Outer / Inner / Leading / Trailing / Bottom and the third table row used to be unreachable:
    /// the renderer looked up a fixed list of area names that never mentioned them.
    @Test func areasOutsideTheOldKeyListRender() {
        let areas: [(ComplicationTemplate, [String])] = [
            (.GraphicCornerGaugeText, ["Outer", "Leading", "Trailing"]),
            (.GraphicCornerStackText, ["Outer", "Inner"]),
            (.GraphicCircularOpenGaugeSimpleText, ["Center", "Bottom"]),
        ]
        for (template, slugs) in areas {
            let textAreas = Dictionary(uniqueKeysWithValues: slugs.map { ($0, (text: $0, color: "#FFFFFFFF")) })
            let render = LegacyComplicationRender(complication: complication(
                family: template.groupMember,
                template: template,
                textAreas: textAreas
            ))
            for slug in slugs {
                #expect(render.inlineText.contains(slug), "\(template.rawValue) dropped \(slug)")
            }
        }
    }

    /// The columns and table templates laid two columns out side by side, so they stay one line each
    /// rather than stacking into four.
    @Test func columnPairsFoldOntoOneLine() {
        let render = LegacyComplicationRender(complication: complication(
            family: .modularLarge,
            template: .ModularLargeColumns,
            textAreas: [
                "Row1Column1": ("Rain", "#FFFFFFFF"),
                "Row1Column2": ("2mm", "#FFFFFFFF"),
                "Row2Column1": ("Wind", "#FFFFFFFF"),
                "Row2Column2": ("3km/h", "#FFFFFFFF"),
            ]
        ))

        #expect(render.title == "Rain  2mm")
        #expect(render.value == "Wind  3km/h")
        #expect(render.bottomText.isEmpty)
    }

    @Test func emptyAreasAreSkipped() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicRectangular,
            template: .GraphicRectangularStandardBody,
            textAreas: [
                "Header": ("Rain", "#FFFFFFFF"),
                "Body1": ("", "#FFFFFFFF"),
                "Body2": ("in 45m", "#FFFFFFFF"),
            ]
        ))

        #expect(render.title == "Rain")
        #expect(render.value == "in 45m")
        #expect(render.bottomText.isEmpty)
    }

    /// A server-rendered template wins over the raw Jinja the area stores.
    @Test func renderedTemplatesWinOverConfiguredText() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerTextImage,
            textAreas: ["Center": ("{{ states('sensor.rain') }}", "#FFFFFFFF")],
            rendered: ["textArea,Center": "▁▂▃"]
        ))

        #expect(render.value == "▁▂▃")
    }

    /// An image-only template has nothing to say, and must not start captioning itself with the
    /// complication's name.
    @Test func imageOnlyTemplateStaysImageOnly() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularImage,
            extra: ["icon": ["icon": "home", "icon_color": "#FFFFFFFF"]]
        ))

        #expect(render.value.isEmpty)
        #expect(render.title.isEmpty)
        #expect(render.iconName == "home")
    }

    /// …but a complication with neither text nor image still needs something on the face.
    @Test func emptyComplicationFallsBackToItsName() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularOpenGaugeSimpleText
        ))

        #expect(render.value == "Rain")
    }

    // MARK: - Gauge

    @Test func ringWinsOverGaugeAndClosedMeansCapacity() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularClosedGaugeText,
            textAreas: ["Center": ("42", "#FFFFFFFF")],
            // Fractions that are exact in binary, so the Float→Double widening the percentile parser
            // does can't turn an equality check into a rounding puzzle.
            rendered: ["ring": "0.25", "gauge": "0.75"],
            extra: [
                "ring": ["ring_value": "{{ 0.25 }}", "ring_color": "#00FF00FF", "ring_type": "closed"],
                "gauge": ["gauge": "{{ 0.75 }}", "gauge_color": "#FF0000FF", "gauge_type": "open"],
            ]
        ))

        #expect(render.fraction == 0.25)
        #expect(render.tint == "#00FF00FF")
        #expect(render.gaugeStyle == WatchComplicationConfig.GaugeStyle.capacity.rawValue)
    }

    @Test func openGaugeMapsToTheOpenArc() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularOpenGaugeSimpleText,
            textAreas: ["Center": ("42", "#FFFFFFFF")],
            extra: ["gauge": ["gauge": "0.5", "gauge_color": "#FF0000FF", "gauge_type": "open"]]
        ))

        #expect(render.fraction == 0.5)
        #expect(render.gaugeStyle == WatchComplicationConfig.GaugeStyle.open.rawValue)
    }

    @Test func noGaugeMeansNoFraction() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerTextImage,
            textAreas: ["Center": ("hi", "#FFFFFFFF")]
        ))

        #expect(render.fraction == nil)
        #expect(render.gaugeStyle == nil)
    }

    // MARK: - Colors

    @Test func graphicFamiliesKeepTheirTextColors() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicRectangular,
            template: .GraphicRectangularStandardBody,
            textAreas: [
                "Header": ("Rain", "#FFFFFFFF"),
                "Body1": ("▁▂▃", "#00FF00FF"),
                "Body2": ("in 45m", "#FF0000FF"),
            ]
        ))

        #expect(render.textColor == "#00FF00FF")
        #expect(render.bottomTextColor == "#FF0000FF")
    }

    /// ClockKit tinted the non-graphic families itself and ignored the picked color, so honoring it
    /// now would repaint complications that have always rendered in the face's own tint.
    @Test func nonGraphicFamiliesIgnoreTextColors() {
        let render = LegacyComplicationRender(complication: complication(
            family: .modularLarge,
            template: .ModularLargeStandardBody,
            textAreas: [
                "Header": ("Rain", "#FFFFFFFF"),
                "Body1": ("▁▂▃", "#00FF00FF"),
                "Body2": ("in 45m", "#FF0000FF"),
            ]
        ))

        #expect(render.textColor == nil)
        #expect(render.bottomTextColor == nil)
    }
}
