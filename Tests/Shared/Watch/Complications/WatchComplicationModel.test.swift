import Foundation
@testable import Shared
import Testing

struct WatchComplicationModelTests {
    private struct NumericDescription: CustomStringConvertible {
        var description: String { "42" }
    }

    private struct UnparseableDescription: CustomStringConvertible {
        var description: String { "not a number" }
    }

    @Test func initDefaultsTheTemplateToTheFamilysFirst() {
        let complication = WatchComplication(family: .graphicCorner)
        #expect(complication.rawFamily == "graphicCorner")
        #expect(complication.Family == .graphicCorner)
        #expect(complication.Template == .GraphicCornerCircularImage)
        #expect(complication.rawTemplate == ComplicationTemplate.GraphicCornerCircularImage.rawValue)
        #expect(complication.isPublic)
        #expect(complication.complicationData == "{}")
        #expect(complication.Data.isEmpty)
    }

    @Test func initKeepsAnExplicitTemplateAndMetadata() {
        let createdAt = Date(timeIntervalSince1970: 1000)
        let complication = WatchComplication(
            identifier: "abc",
            serverIdentifier: "server",
            family: .modularLarge,
            template: .ModularLargeTable,
            createdAt: createdAt,
            name: "Weather",
            isPublic: false
        )
        #expect(complication.identifier == "abc")
        #expect(complication.serverIdentifier == "server")
        #expect(complication.Template == .ModularLargeTable)
        #expect(complication.createdAt == createdAt)
        #expect(complication.name == "Weather")
        #expect(complication.isPublic == false)
    }

    @Test func unknownRawValuesFallBack() {
        var complication = WatchComplication(family: .utilitarianLarge)
        complication.rawFamily = "bogus"
        complication.rawTemplate = "bogus"
        #expect(complication.Family == .modularSmall)
        #expect(complication.Template == ComplicationGroupMember.modularSmall.templates.first)

        complication.Family = .extraLarge
        complication.Template = .ExtraLargeSimpleText
        #expect(complication.rawFamily == "extraLarge")
        #expect(complication.rawTemplate == "ExtraLargeSimpleText")
    }

    @Test func dataRoundTripsThroughJSONText() {
        var complication = WatchComplication()
        complication.Data = ["gauge": ["gauge": "0.5"], "count": 3]
        #expect(complication.complicationData != nil)
        #expect((complication.Data["gauge"] as? [String: String])?["gauge"] == "0.5")
        #expect(complication.Data["count"] as? Int == 3)

        complication.complicationData = "not json"
        #expect(complication.Data.isEmpty)

        complication.complicationData = nil
        #expect(complication.Data.isEmpty)
    }

    @Test func displayNamePrefersTheName() {
        var complication = WatchComplication(family: .graphicBezel)
        #expect(complication.displayName == ComplicationTemplate.GraphicBezelCircularText.style)
        complication.name = "Custom"
        #expect(complication.displayName == "Custom")
    }

    @Test func renderedValueTypeParsesAndPrints() {
        #expect(WatchComplication.RenderedValueType(stringValue: "textArea,Center") == .textArea("Center"))
        #expect(WatchComplication.RenderedValueType(stringValue: "gauge") == .gauge)
        #expect(WatchComplication.RenderedValueType(stringValue: "ring") == .ring)
        #expect(WatchComplication.RenderedValueType(stringValue: "textArea") == nil)
        #expect(WatchComplication.RenderedValueType(stringValue: "other") == nil)
        #expect(WatchComplication.RenderedValueType.textArea("Line1").stringValue == "textArea,Line1")
        #expect(WatchComplication.RenderedValueType.gauge.stringValue == "gauge")
        #expect(WatchComplication.RenderedValueType.ring.stringValue == "ring")
    }

    @Test func rawRenderedOnlyIncludesTemplatedValues() {
        var complication = WatchComplication(family: .graphicCircular, template: .GraphicCircularOpenGaugeRangeText)
        complication.Data = [
            "textAreas": [
                "Center": ["text": "{{ states('sensor.a') }}", "color": "#FFFFFFFF"],
                "Leading": ["text": "static", "color": "#FFFFFFFF"],
            ],
            "gauge": ["gauge": "{{ 0.5 }}"],
            "ring": ["ring_value": "{% if true %}1{% endif %}"],
        ]

        let rendered = complication.rawRendered()
        #expect(rendered == [
            "textArea,Center": "{{ states('sensor.a') }}",
            "gauge": "{{ 0.5 }}",
            "ring": "{% if true %}1{% endif %}",
        ])
    }

    @Test func rawRenderedSkipsStaticGaugeAndRing() {
        var complication = WatchComplication(family: .graphicCircular, template: .GraphicCircularOpenGaugeRangeText)
        complication.Data = [
            "gauge": ["gauge": "0.5"],
            "ring": ["ring_value": "1"],
        ]
        #expect(complication.rawRendered().isEmpty)
    }

    @Test func updateRawRenderedStoresTheResponseForRenderedValues() {
        var complication = WatchComplication()
        complication.updateRawRendered(from: [
            "textArea,Center": "21 °C",
            "gauge": 0.25,
            "unknown": "ignored",
        ])

        let values = complication.renderedValues()
        #expect(values.count == 2)
        #expect(values[.textArea("Center")] as? String == "21 °C")
        #expect(values[.gauge] as? Double == 0.25)
        #expect(values[.ring] == nil)
    }

    @Test func renderedValuesIsEmptyWithoutRenders() {
        #expect(WatchComplication().renderedValues().isEmpty)
    }

    @Test func percentileNumberParsesStrings() {
        #expect(WatchComplication.percentileNumber(from: "0.33") == 0.33 as Float)
        #expect(WatchComplication.percentileNumber(from: "1") == 1 as Float)
        #expect(WatchComplication.percentileNumber(from: "abc") == nil)
    }

    @Test func percentileNumberConvertsNumbers() {
        #expect(WatchComplication.percentileNumber(from: 3) == 3 as Float)
        #expect(WatchComplication.percentileNumber(from: 0.5 as Double) == 0.5 as Float)
        #expect(WatchComplication.percentileNumber(from: 0.25 as Float) == 0.25 as Float)
    }

    @Test func percentileNumberFallsBackToTheDescription() {
        #expect(WatchComplication.percentileNumber(from: NumericDescription()) == 42 as Float)
        #expect(WatchComplication.percentileNumber(from: UnparseableDescription()) == nil)
    }
}
