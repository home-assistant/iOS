import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Legacy `WatchComplication` accessors and rendering helpers, plus the database-backed queries of
/// both complication models, against an in-memory database per test.
@Suite(.isolatedEnvironment)
struct WatchComplicationStoreTests {
    private func installDatabase() throws {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }
    }

    @Test func typedAccessorsFallBackForUnknownRawValues() {
        var complication = WatchComplication(family: .graphicCircular, data: ["a": 1])
        #expect(complication.Family == .graphicCircular)
        complication.rawFamily = "bogus"
        complication.rawTemplate = "bogus"
        #expect(complication.Family == .modularSmall)
        #expect(complication.Template == ComplicationGroupMember.modularSmall.templates.first)
        complication.Family = .utilitarianLarge
        complication.Template = .UtilitarianLargeFlat
        #expect(complication.rawTemplate == "UtilitarianLargeFlat")
        #expect(complication.displayName == ComplicationTemplate.UtilitarianLargeFlat.style)
        complication.name = "Named"
        #expect(complication.displayName == "Named")

        complication.complicationData = "not json"
        #expect(complication.Data.isEmpty)
        complication.complicationData = nil
        #expect(complication.Data.isEmpty)
    }

    @Test func renderedValuesRoundTrip() {
        var complication = WatchComplication(data: [
            "textAreas": [
                "Line1": ["text": "{{ states('sensor.x') }}"],
                "Line2": ["text": "plain"],
            ],
            "gauge": ["gauge": "{{ 0.5 }}"],
            "ring": ["ring_value": "{{ 0.25 }}"],
        ])
        let raw = complication.rawRendered()
        #expect(raw.keys.sorted() == ["gauge", "ring", "textArea,Line1"])

        complication.updateRawRendered(from: ["textArea,Line1": "42", "gauge": "0.5", "ring": "0.25", "junk": "x"])
        let rendered = complication.renderedValues()
        #expect(rendered[.textArea("Line1")] as? String == "42")
        #expect(rendered[.gauge] as? String == "0.5")
        #expect(rendered.count == 3)
        #expect(WatchComplication.RenderedValueType(stringValue: "textArea") == nil)
        #expect(WatchComplication.RenderedValueType(stringValue: "ring")?.stringValue == "ring")
    }

    @Test func percentilesParseEveryNumericShape() {
        #expect(WatchComplication.percentileNumber(from: "0.33") == 0.33)
        #expect(WatchComplication.percentileNumber(from: 2) == 2)
        #expect(WatchComplication.percentileNumber(from: 0.5 as Double) == 0.5)
        #expect(WatchComplication.percentileNumber(from: Float(0.75)) == 0.75)
        #expect(WatchComplication.percentileNumber(from: "abc") == nil)
        #expect(WatchComplication.percentileNumber(from: NSNumber(value: 1)) != nil)
    }

    @Test func legacyComplicationsPersist() throws {
        try installDatabase()
        let first = WatchComplication(
            identifier: "one",
            serverIdentifier: "s1",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let second = WatchComplication(
            identifier: "two",
            serverIdentifier: "s2",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        try first.save()
        try second.save()
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplication.all().map(\.identifier) == ["one", "two"])
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplication.all(forServerIdentifier: "s2").map(\.identifier) == ["two"])

        try WatchComplication.deleteOrphans(keepingServerIdentifiers: ["s1"])
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplication.all().map(\.identifier) == ["one"])
        try first.delete()
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplication.all().isEmpty)

        try WatchComplication.replaceAll([first, second])
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplication.all().count == 2)
    }

    @Test func complicationConfigsPersist() throws {
        try installDatabase()
        let a = WatchComplicationConfig(id: "a", serverId: "s1", sortOrder: 1)
        let b = WatchComplicationConfig(id: "b", serverId: "s2", sortOrder: 0)
        try a.save()
        try b.save()
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplicationConfig.all().map(\.id) == ["b", "a"])
        try WatchComplicationConfig.deleteOrphans(keepingServerIds: ["s1"])
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplicationConfig.all().map(\.id) == ["a"])
        try a.delete()
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplicationConfig.all().isEmpty)
        try WatchComplicationConfig.replaceAll([a, b])
        // swiftformat:disable:next hoistTry
        #expect(try WatchComplicationConfig.all().count == 2)
    }

    @Test func configOptionTitlesAreLocalized() {
        for style in WatchComplicationConfig.GaugeStyle.allCases {
            #expect(!style.title.isEmpty)
        }
        for display in WatchComplicationConfig.CornerGaugeDisplay.allCases {
            #expect(!display.title.isEmpty)
        }
        let familyTitles = WatchComplicationConfig.Family.allCases.map(\.title)
        #expect(Set(familyTitles).count == WatchComplicationConfig.Family.allCases.count)
    }
}
