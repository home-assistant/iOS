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

    /// The rectangular "Standard Body" complication behind the three-line status recipe: ClockKit never
    /// drew an icon for it, even though the editor stored one. The stored icon must stay off the face,
    /// or it pushes all three lines over and truncates them.
    @Test func textOnlyTemplateIgnoresItsStoredIcon() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicRectangular,
            template: .GraphicRectangularStandardBody,
            textAreas: [
                "Header": ("Rain", "#FFFFFFFF"),
                "Body1": ("▁▂▃", "#00FF00FF"),
                "Body2": ("in 45m", "#FF0000FF"),
            ],
            extra: ["icon": ["icon": "mdi:home", "icon_color": "#FFFFFFFF"]]
        ))

        #expect(render.iconName == nil)
        #expect(render.iconColor == nil)
        #expect(render.title == "Rain")
        #expect(render.value == "▁▂▃")
        #expect(render.bottomText == "in 45m")
    }

    /// The same goes for the rectangular "Text Gauge" and the Modular Large templates, whose ClockKit
    /// header image this app never filled either.
    @Test func otherTextOnlyTemplatesIgnoreTheirStoredIcon() {
        let cases: [(ComplicationGroupMember, ComplicationTemplate)] = [
            (.graphicRectangular, .GraphicRectangularTextGauge),
            (.modularLarge, .ModularLargeStandardBody),
            (.modularLarge, .ModularLargeColumns),
            (.modularLarge, .ModularLargeTable),
        ]
        for (family, template) in cases {
            let render = LegacyComplicationRender(complication: complication(
                family: family,
                template: template,
                textAreas: ["Header": ("Rain", "#FFFFFFFF"), "Body1": ("▁▂▃", "#FFFFFFFF")],
                extra: ["icon": ["icon": "mdi:home", "icon_color": "#FFFFFFFF"]]
            ))

            #expect(render.iconName == nil, "\(template) must not render an icon")
        }
    }

    /// …while the "Large Image" template, whose whole point is the image, keeps it.
    @Test func imageTemplateKeepsItsIcon() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicRectangular,
            template: .GraphicRectangularLargeImage,
            textAreas: ["Header": ("Rain", "#FFFFFFFF")],
            extra: ["icon": ["icon": "mdi:home", "icon_color": "#FFFFFFFF"]]
        ))

        #expect(render.iconName == "mdi:home")
        #expect(render.iconColor == "#FFFFFFFF")
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

    // MARK: - Content-led families (corner and circular)

    /// The corner and circular templates have no `Header`: they lead with the content and caption it
    /// after. WidgetKit draws an `accessoryCorner` widget's own content on the outside of the curve and
    /// its `widgetLabel` on the inside — where ClockKit's `outerTextProvider` drew too — and the
    /// circular face stacks its value above its name. So the first area has to be the value there,
    /// the opposite of the label-then-content reading above.
    @Test func contentLedKeepsTheFirstAreaAsTheValue() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerStackText,
            textAreas: ["Inner": ("inner", "#00FF00FF"), "Outer": ("outer", "#268BD2FF")]
        ))

        #expect(render.contentLed.value == "outer")
        #expect(render.contentLed.title == "inner")
        // The color follows the text it was picked for, so it swaps with it.
        #expect(render.contentLed.textColor == "#268BD2FF")
    }

    /// The circular open gauge's Center area is its big number and Bottom is the caption under it —
    /// not the other way round, which would read the subtext as the value.
    @Test func circularOpenGaugeLeadsWithItsCenterArea() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularOpenGaugeSimpleText,
            textAreas: ["Center": ("21.5°", "#268BD2FF"), "Bottom": ("now", "#FFFFFFFF")]
        ))

        #expect(render.contentLed.value == "21.5°")
        #expect(render.contentLed.title == "now")
    }

    /// The long-standing rain-sparkline recipe: a single Center area rendering a block-element bar
    /// graph, plus an icon. The graph is the complication's whole content, so it belongs in the corner
    /// itself — demoting it to the bezel re-typesets it small and rotates it glyph by glyph, which is
    /// exactly what a bar graph can't survive.
    @Test func contentLedSingleAreaIsTheContent() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerTextImage,
            textAreas: ["Center": ("{{ states('sensor.rain') }}", "#268BD2FF")],
            rendered: ["textArea,Center": "▁▂▃▄▅▆▇█"],
            extra: ["icon": ["icon": "weather_rainy", "icon_color": "#FFFFFFFF"]]
        ))

        #expect(render.contentLed.value == "▁▂▃▄▅▆▇█")
        #expect(render.contentLed.title.isEmpty)
        #expect(render.iconName == "weather_rainy")
    }

    /// An image-only template fills neither position, so the face can leave the bezel label off instead
    /// of drawing an empty one.
    @Test func contentLedWithoutTextFillsNeitherPosition() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerCircularImage,
            extra: ["icon": ["icon": "ab_testing", "icon_color": "#30D158FF"]]
        ))

        #expect(render.contentLed.value.isEmpty)
        #expect(render.contentLed.title.isEmpty)
    }

    // MARK: - Gauge end labels

    /// Leading and Trailing label the two ends of the gauge — they are not body text. Reading them as
    /// text slots made the gauge's minimum the complication's value and dropped the maximum entirely.
    @Test func gaugeEndLabelsGoToTheGaugeNotTheTextSlots() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularOpenGaugeRangeText,
            textAreas: [
                "Center": ("21.5", "#AA00FFFF"),
                "Leading": ("16", "#268BD2FF"),
                "Trailing": ("30", "#DC322FFF"),
            ],
            extra: ["gauge": ["gauge": "0.5", "gauge_type": "open", "gauge_color": "#268BD2FF"]]
        ))

        #expect(render.minLabel == "16")
        #expect(render.maxLabel == "30")
        // The value is the Center area, and neither end label captions it.
        #expect(render.contentLed.value == "21.5")
        #expect(render.contentLed.title.isEmpty)
        #expect(render.bottomText.isEmpty)
    }

    /// The corner gauge variant leads with its Outer area, with Leading / Trailing going to the gauge.
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

        #expect(render.contentLed.value == "21.5°")
        #expect(render.contentLed.title.isEmpty)
        #expect(render.minLabel == "16")
        #expect(render.maxLabel == "30")
    }

    /// A gauge template whose only filled areas are its end labels still has the gauge to show, so it
    /// must not fall through to captioning itself with the complication's name.
    @Test func gaugeEndLabelsAloneAreNotAnEmptyComplication() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCorner,
            template: .GraphicCornerGaugeImage,
            textAreas: ["Leading": ("16", "#FFFFFFFF"), "Trailing": ("30", "#FFFFFFFF")]
        ))

        #expect(render.minLabel == "16")
        #expect(render.maxLabel == "30")
        #expect(render.value.isEmpty)
        #expect(render.contentLed.value.isEmpty)
        #expect(render.inlineText == "16 30")
    }

    /// Inline draws no gauge, so its one line still has to carry the end labels — they have nowhere
    /// else to go there.
    @Test func inlineStillCarriesTheGaugeEndLabels() {
        let render = LegacyComplicationRender(complication: complication(
            family: .graphicCircular,
            template: .GraphicCircularOpenGaugeRangeText,
            textAreas: [
                "Center": ("21.5", "#FFFFFFFF"),
                "Leading": ("16", "#FFFFFFFF"),
                "Trailing": ("30", "#FFFFFFFF"),
            ]
        ))

        #expect(render.inlineText == "21.5 16 30")
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
