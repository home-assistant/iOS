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

    // MARK: - Corner family

    /// The corner is the one family that doesn't stack a label above its content: WidgetKit draws an
    /// `accessoryCorner` widget's own content on the outside of the curve and its `widgetLabel` on the
    /// inside, and ClockKit's `outerTextProvider` was likewise the outer line. So the first area has to
    /// stay on the outside there, which is the opposite of the label-then-content reading above.
    @Test func cornerKeepsTheOuterAreaOutside() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerStackText,
            textAreas: ["Inner": ("inner", "#00FF00FF"), "Outer": ("outer", "#268BD2FF")]
        ))

        #expect(render.corner.value == "outer")
        #expect(render.corner.title == "inner")
        // The color follows the text it was picked for, so it swaps with it.
        #expect(render.corner.textColor == "#268BD2FF")
    }

    /// The long-standing rain-sparkline recipe: a single Center area rendering a block-element bar
    /// graph, plus an icon. The graph is the complication's whole content, so it belongs in the corner
    /// itself — demoting it to the bezel re-typesets it small and rotates it glyph by glyph, which is
    /// exactly what a bar graph can't survive.
    @Test func cornerSingleAreaIsTheCornerContent() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerTextImage,
            textAreas: ["Center": ("{{ states('sensor.rain') }}", "#268BD2FF")],
            rendered: ["textArea,Center": "▁▂▃▄▅▆▇█"],
            extra: ["icon": ["icon": "weather_rainy", "icon_color": "#FFFFFFFF"]]
        ))

        #expect(render.corner.value == "▁▂▃▄▅▆▇█")
        #expect(render.corner.title.isEmpty)
        #expect(render.iconName == "weather_rainy")
    }

    /// The gauge variant leads with its Outer area too, with the gauge's end labels behind it.
    @Test func cornerGaugeTextLeadsWithItsOuterArea() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerGaugeText,
            textAreas: [
                "Outer": ("21.5°", "#FFFFFFFF"),
                "Leading": ("16", "#FFFFFFFF"),
                "Trailing": ("30", "#FFFFFFFF"),
            ]
        ))

        #expect(render.corner.value == "21.5°")
        #expect(render.corner.title == "16")
    }

    /// An image-only template fills neither corner position, so the face can leave the bezel label off
    /// instead of drawing an empty one.
    @Test func cornerWithoutTextFillsNeitherPosition() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerCircularImage,
            extra: ["icon": ["icon": "ab_testing", "icon_color": "#30D158FF"]]
        ))

        #expect(render.corner.value.isEmpty)
        #expect(render.corner.title.isEmpty)
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

    /// An empty first column drops out, and its second column has to start its own line rather than
    /// folding onto the row above it.
    @Test func secondColumnDoesNotFoldOntoThePreviousRow() {
        let render = LegacyComplicationRender(complication: complication(
            family: .modularLarge,
            template: .ModularLargeColumns,
            textAreas: [
                "Row1Column1": ("Rain", "#FFFFFFFF"),
                "Row1Column2": ("2mm", "#FFFFFFFF"),
                "Row2Column1": ("", "#FFFFFFFF"),
                "Row2Column2": ("3km/h", "#FFFFFFFF"),
            ]
        ))

        #expect(render.title == "Rain  2mm")
        #expect(render.value == "3km/h")
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
        // Inline has no icon to fall back on, so it borrows the complication's name rather than
        // rendering as the app itself.
        #expect(render.inlineText == "Rain")
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
