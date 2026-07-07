import Foundation
import GRDB
@testable import Shared
import XCTest

class WatchComplicationTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try WatchComplicationTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }
    }

    override func tearDown() {
        Current.database = previousDatabase

        super.tearDown()
    }

    private func makeComplication() -> WatchComplication {
        let complication = WatchComplication()
        complication.identifier = "test-identifier"
        complication.serverIdentifier = "server1"
        complication.Family = .graphicCircular
        complication.Template = .GraphicCircularImage
        complication.name = "My Complication"
        complication.isPublic = false
        complication.Data = [
            "icon": [
                "icon": "mdi:lightbulb",
                "icon_color": "#ff0000",
            ],
        ]
        return complication
    }

    // MARK: - Wire format (phone to watch sync)

    func testObjectMapperWireKeysAreStable() {
        let json = makeComplication().toJSON()

        // these keys are the watch<->app wire format and must not change,
        // otherwise complication sync breaks across mixed app versions
        XCTAssertEqual(json["identifier"] as? String, "test-identifier")
        XCTAssertEqual(json["serverIdentifier"] as? String, "server1")
        XCTAssertEqual(json["Family"] as? String, ComplicationGroupMember.graphicCircular.rawValue)
        XCTAssertEqual(json["Template"] as? String, ComplicationTemplate.GraphicCircularImage.rawValue)
        XCTAssertEqual(json["name"] as? String, "My Complication")
        XCTAssertEqual(json["IsPublic"] as? Bool, false)
        XCTAssertNotNil(json["CreatedAt"])
        XCTAssertNotNil(json["Data"])
    }

    func testObjectMapperRoundTrip() throws {
        let original = makeComplication()

        let decoded = try WatchComplication(JSON: original.toJSON())

        XCTAssertEqual(decoded.identifier, original.identifier)
        XCTAssertEqual(decoded.serverIdentifier, original.serverIdentifier)
        XCTAssertEqual(decoded.Family, original.Family)
        XCTAssertEqual(decoded.Template, original.Template)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.isPublic, original.isPublic)
        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            original.createdAt.timeIntervalSince1970,
            accuracy: 1
        )
        XCTAssertEqual(decoded.Data["icon"] as? [String: String], original.Data["icon"] as? [String: String])
    }

    // MARK: - Persistence

    func testDatabaseRoundTrip() throws {
        let original = makeComplication()
        original.save()

        let fetched = try XCTUnwrap(WatchComplication.fetch(identifier: "test-identifier"))
        XCTAssertEqual(fetched.identifier, original.identifier)
        XCTAssertEqual(fetched.serverIdentifier, original.serverIdentifier)
        XCTAssertEqual(fetched.Family, original.Family)
        XCTAssertEqual(fetched.Template, original.Template)
        XCTAssertEqual(fetched.name, original.name)
        XCTAssertEqual(fetched.isPublic, original.isPublic)
        XCTAssertEqual(fetched.Data["icon"] as? [String: String], original.Data["icon"] as? [String: String])
    }

    func testComplicationsByServerAndReplaceAll() {
        let first = makeComplication()
        first.identifier = "c1"
        first.serverIdentifier = "server1"
        first.save()

        let second = makeComplication()
        second.identifier = "c2"
        second.serverIdentifier = "server2"
        second.save()

        XCTAssertEqual(WatchComplication.complications(serverIdentifier: "server1").map(\.identifier), ["c1"])
        XCTAssertEqual(WatchComplication.all().count, 2)

        let replacement = makeComplication()
        replacement.identifier = "c3"
        WatchComplication.replaceAll(with: [replacement])

        XCTAssertEqual(WatchComplication.all().map(\.identifier), ["c3"])
    }

    func testDelete() {
        let complication = makeComplication()
        complication.save()
        XCTAssertEqual(WatchComplication.all().count, 1)

        complication.delete()
        XCTAssertEqual(WatchComplication.all().count, 0)
    }

    // MARK: - Family/Template fallbacks

    func testFamilyAndTemplateFallbacks() {
        let complication = WatchComplication()

        // raw values default to empty strings, which fall back to defaults
        XCTAssertEqual(complication.Family, .modularSmall)
        XCTAssertEqual(complication.Template, ComplicationGroupMember.modularSmall.templates.first)

        complication.Family = .utilitarianSmall
        XCTAssertEqual(complication.Family, .utilitarianSmall)
    }

    // MARK: - Template rendering bookkeeping

    func testRawRenderedAndRenderedValues() {
        let complication = WatchComplication()
        complication.identifier = "rendered"
        complication.Data = [
            "textAreas": [
                "Line1": ["text": "{{ states('sensor.one') }}", "color": "#ffffff"],
                "Line2": ["text": "static text", "color": "#ffffff"],
            ],
            "gauge": ["gauge": "{{ states('sensor.two') }}"],
            "ring": ["ring_value": "{{ states('sensor.three') }}"],
        ]

        // only jinja-templated values need rendering
        let rawRendered = complication.rawRendered()
        XCTAssertEqual(rawRendered["textArea,Line1"], "{{ states('sensor.one') }}")
        XCTAssertNil(rawRendered["textArea,Line2"])
        XCTAssertEqual(rawRendered["gauge"], "{{ states('sensor.two') }}")
        XCTAssertEqual(rawRendered["ring"], "{{ states('sensor.three') }}")

        complication.updateRawRendered(from: [
            "textArea,Line1": "one",
            "gauge": "0.5",
            "ring": "0.25",
        ])
        complication.save()

        guard let fetched = WatchComplication.fetch(identifier: "rendered") else {
            XCTFail("expected complication to be persisted")
            return
        }
        let rendered = fetched.renderedValues()
        XCTAssertEqual(rendered[.textArea("Line1")] as? String, "one")
        XCTAssertEqual(rendered[.gauge] as? String, "0.5")
        XCTAssertEqual(rendered[.ring] as? String, "0.25")
    }

    // MARK: - Equality

    func testEqualityAndHashingByIdentifier() {
        let first = makeComplication()
        let second = makeComplication()
        second.name = "Other Name"

        // identity is the identifier, matching the previous primary-key semantics
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set([first, second]).count, 1)

        second.identifier = "other-identifier"
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Percentiles

    func testPercentileNumber() {
        XCTAssertEqual(WatchComplication.percentileNumber(from: "0.33"), 0.33)
        XCTAssertEqual(WatchComplication.percentileNumber(from: 1), 1)
        XCTAssertEqual(WatchComplication.percentileNumber(from: 0.5), 0.5)
        XCTAssertEqual(WatchComplication.percentileNumber(from: Float(0.25)), 0.25)
        XCTAssertNil(WatchComplication.percentileNumber(from: "not a number"))
    }
}
