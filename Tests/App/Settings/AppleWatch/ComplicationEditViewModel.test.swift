import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// The legacy complication editor reads a free-form `Data` blob into typed editor state and writes it
/// back on save; these pin that round trip, the template-driven gating and the preview validation.
@MainActor
@Suite(.serialized)
struct ComplicationEditViewModelTests {
    // MARK: - Parsing saved data

    @Test func parsesGaugeAndTextAreasAndForcesTheOpenGaugeStyle() throws {
        try withWorld { _ in
            let config = WatchComplication(
                family: .graphicCircular,
                template: .GraphicCircularOpenGaugeRangeText,
                data: [
                    "gauge": [
                        "gauge": "0.5",
                        "gauge_color": "#FF0000",
                        "gauge_type": "Closed",
                        "gauge_style": "Ring",
                    ],
                    "textAreas": [
                        "Center": ["text": "Middle", "color": "#00FF00"],
                    ],
                ],
                name: "Gauge"
            )
            let viewModel = ComplicationEditViewModel(config: config, isNew: false)

            #expect(viewModel.name == "Gauge")
            #expect(!viewModel.isNew)
            #expect(viewModel.family == .graphicCircular)
            #expect(viewModel.gaugeTemplate == "0.5")
            // The template only renders an open gauge, overriding the saved "closed".
            #expect(viewModel.gaugeType == .open)
            #expect(viewModel.isGaugeTypeForced)
            #expect(viewModel.gaugeStyle == .ring)
            #expect(viewModel.hasGauge)
            #expect(!viewModel.hasRing)
            #expect(!viewModel.hasImage)
            #expect(!viewModel.supportsColumn2Alignment)
            #expect(viewModel.activeTextAreas == [.Center, .Leading, .Trailing])
            #expect(viewModel.textAreaValues["Center"]?.text == "Middle")
            #expect(viewModel.textAreaValues["Leading"]?.text == "")
            #expect(viewModel.textAreaValues.count == ComplicationTextAreas.allCases.count)
        }
    }

    @Test func parsesRingAndIcon() throws {
        try withWorld { _ in
            let config = WatchComplication(
                family: .circularSmall,
                template: .CircularSmallRingImage,
                data: [
                    "ring": ["ring_value": "0.3", "ring_color": "#0000FF", "ring_type": "closed"],
                    "icon": ["icon": "home", "icon_color": "#FFFFFF"],
                ]
            )
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)

            #expect(viewModel.isNew)
            #expect(viewModel.name.isEmpty)
            #expect(viewModel.ringTemplate == "0.3")
            #expect(viewModel.ringType == .closed)
            #expect(viewModel.icon.name == "home")
            #expect(viewModel.hasRing)
            #expect(viewModel.hasImage)
            #expect(!viewModel.hasGauge)
            #expect(viewModel.activeTextAreas.isEmpty)
        }
    }

    @Test func parsesColumn2Alignment() throws {
        try withWorld { _ in
            let config = WatchComplication(
                family: .modularLarge,
                template: .ModularLargeColumns,
                data: ["column2alignment": ["column2alignment": "Trailing"]]
            )
            let viewModel = ComplicationEditViewModel(config: config, isNew: false)
            #expect(viewModel.supportsColumn2Alignment)
            #expect(viewModel.column2Alignment == .trailing)
        }
    }

    @Test func emptyDataFallsBackToDefaults() throws {
        try withWorld { _ in
            let viewModel = ComplicationEditViewModel(
                config: WatchComplication(family: .modularLarge, template: .ModularLargeColumns),
                isNew: true
            )
            #expect(viewModel.column2Alignment == .leading)
            #expect(viewModel.gaugeTemplate.isEmpty)
            #expect(viewModel.ringTemplate.isEmpty)
            #expect(viewModel.gaugeType == .open)
            #expect(viewModel.gaugeStyle == .fill)
            #expect(viewModel.ringType == .open)
            #expect(viewModel.isPublic)
        }
    }

    // MARK: - Template changes

    @Test func changingToAClosedGaugeTemplateForcesTheClosedType() throws {
        try withWorld { _ in
            let viewModel = ComplicationEditViewModel(
                config: WatchComplication(family: .graphicCircular, template: .GraphicCircularOpenGaugeImage),
                isNew: true
            )
            #expect(viewModel.gaugeType == .open)

            viewModel.displayTemplate = .GraphicCircularClosedGaugeText
            viewModel.onDisplayTemplateChange()
            #expect(viewModel.gaugeType == .closed)

            // A template that can render either style leaves the user's choice alone.
            viewModel.displayTemplate = .GraphicRectangularTextGauge
            viewModel.gaugeType = .open
            viewModel.onDisplayTemplateChange()
            #expect(viewModel.gaugeType == .open)
            #expect(!viewModel.isGaugeTypeForced)
        }
    }

    // MARK: - Validation

    @Test func validityRequiresEveryActiveInput() throws {
        try withWorld { _ in
            let viewModel = ComplicationEditViewModel(
                config: WatchComplication(family: .graphicCorner, template: .GraphicCornerGaugeText),
                isNew: true
            )
            #expect(!viewModel.isValid)

            viewModel.gaugeTemplate = "0.5"
            #expect(!viewModel.isValid)

            for area in viewModel.activeTextAreas {
                viewModel.textAreaValues[area.slug] = .init(text: "Text", color: .green)
            }
            #expect(viewModel.isValid)

            let ring = ComplicationEditViewModel(
                config: WatchComplication(family: .circularSmall, template: .CircularSmallRingImage),
                isNew: true
            )
            #expect(!ring.isValid)
            ring.ringTemplate = "0.4"
            #expect(ring.isValid)
        }
    }

    // MARK: - Server

    @Test func keepsItsSavedServerAndFallsBackToTheFirstOne() throws {
        try withWorld(serverIds: ["server-1", "server-2"]) { _ in
            let saved = ComplicationEditViewModel(
                config: WatchComplication(serverIdentifier: "server-2", family: .modularSmall),
                isNew: false
            )
            #expect(saved.serverIdentifier == "server-2")
            #expect(saved.server?.identifier.rawValue == "server-2")

            let unknown = ComplicationEditViewModel(
                config: WatchComplication(serverIdentifier: "gone", family: .modularSmall),
                isNew: false
            )
            #expect(unknown.serverIdentifier == "server-1")

            unknown.serverIdentifier = nil
            #expect(unknown.server?.identifier.rawValue == "server-1")
        }
    }

    // MARK: - Save / delete

    @Test func savePersistsTheSerializedEditorState() throws {
        // No server: the save stays local instead of reaching for an API.
        try withWorld(serverIds: []) { database in
            let config = WatchComplication(
                identifier: "complication-1",
                family: .graphicCorner,
                template: .GraphicCornerGaugeImage
            )
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)
            viewModel.name = "Battery"
            viewModel.isPublic = false
            viewModel.gaugeTemplate = "0.75"
            viewModel.gaugeType = .closed
            viewModel.gaugeStyle = .ring
            viewModel.icon = MaterialDesignIcons(named: "battery")
            for area in viewModel.activeTextAreas {
                viewModel.textAreaValues[area.slug] = .init(text: "Corner text", color: .red)
            }

            var notified = false
            let token = NotificationCenter.default.addObserver(
                forName: WatchComplication.didChangeNotification,
                object: nil,
                queue: nil
            ) { _ in notified = true }
            defer { NotificationCenter.default.removeObserver(token) }

            viewModel.save()

            let fetched = try database.read { db in
                try WatchComplication.fetchOne(db, key: "complication-1")
            }
            let saved = try #require(fetched)
            #expect(notified)
            #expect(saved.name == "Battery")
            #expect(!saved.isPublic)
            #expect(saved.serverIdentifier == nil)
            #expect(saved.Template == .GraphicCornerGaugeImage)

            let data = saved.Data
            let gauge = try #require(data["gauge"] as? [String: Any])
            #expect(gauge["gauge"] as? String == "0.75")
            #expect(gauge["gauge_type"] as? String == "closed")
            #expect(gauge["gauge_style"] as? String == "ring")
            #expect(gauge["gauge_color"] is String)

            let icon = try #require(data["icon"] as? [String: Any])
            #expect(icon["icon"] as? String == "battery")
            #expect(data["ring"] == nil)
            #expect(data["column2alignment"] == nil)

            let textAreas = try #require(data["textAreas"] as? [String: [String: Any]])
            #expect(Set(textAreas.keys) == Set(viewModel.activeTextAreas.map(\.slug)))
            #expect(textAreas["Leading"]?["text"] as? String == "Corner text")
        }
    }

    @Test func saveWritesRingAndColumnAlignmentAndClearsAnEmptyName() throws {
        try withWorld(serverIds: []) { database in
            let ring = ComplicationEditViewModel(
                config: WatchComplication(identifier: "ring", family: .circularSmall, template: .CircularSmallRingText),
                isNew: true
            )
            ring.name = ""
            ring.ringTemplate = "0.2"
            ring.ringType = .closed
            ring.save()

            let columns = ComplicationEditViewModel(
                config: WatchComplication(identifier: "columns", family: .modularLarge, template: .ModularLargeColumns),
                isNew: true
            )
            columns.column2Alignment = .trailing
            columns.save()

            let fetchedRing = try database.read { db in
                try WatchComplication.fetchOne(db, key: "ring")
            }
            let savedRing = try #require(fetchedRing)
            #expect(savedRing.name == nil)
            let ringData = try #require(savedRing.Data["ring"] as? [String: Any])
            #expect(ringData["ring_value"] as? String == "0.2")
            #expect(ringData["ring_type"] as? String == "closed")

            let fetchedColumns = try database.read { db in
                try WatchComplication.fetchOne(db, key: "columns")
            }
            let savedColumns = try #require(fetchedColumns)
            let alignment = try #require(savedColumns.Data["column2alignment"] as? [String: Any])
            #expect(alignment["column2alignment"] as? String == "trailing")
        }
    }

    @Test func deleteRemovesTheRow() throws {
        try withWorld(serverIds: []) { database in
            let config = WatchComplication(identifier: "to-delete", family: .utilitarianLarge)
            try config.save()
            let countBefore = try database.read { db in try WatchComplication.fetchCount(db) }
            #expect(countBefore == 1)

            ComplicationEditViewModel(config: config, isNew: false).delete()

            let countAfter = try database.read { db in try WatchComplication.fetchCount(db) }
            #expect(countAfter == 0)
        }
    }

    // MARK: - Preview validation

    @Test func percentileValidationAcceptsFractionsOnly() throws {
        let fromString = try ComplicationEditViewModel.validatePercentile("0.5")
        let fromDouble = try ComplicationEditViewModel.validatePercentile(0.25)
        let fromInt = try ComplicationEditViewModel.validatePercentile(1)
        #expect(fromString == "0.5")
        #expect(fromDouble == "0.25")
        #expect(fromInt == "1")

        #expect(throws: ComplicationEditViewModel.RenderValueError.self) {
            try ComplicationEditViewModel.validatePercentile(2)
        }
        #expect(throws: ComplicationEditViewModel.RenderValueError.self) {
            try ComplicationEditViewModel.validatePercentile("not a number")
        }
    }

    @Test func renderErrorsDescribeTheProblem() {
        let notNumber = ComplicationEditViewModel.RenderValueError.expectedFloat(value: "abc")
        #expect(notNumber.errorDescription == L10n.Watch.Configurator.PreviewError.notNumber("string", "abc"))

        let outOfRange = ComplicationEditViewModel.RenderValueError.outOfRange(value: 2)
        #expect(outOfRange.errorDescription == L10n.Watch.Configurator.PreviewError.outOfRange(2))

        let notNumberInt = ComplicationEditViewModel.RenderValueError.expectedFloat(value: [1])
        #expect(notNumberInt.errorDescription?.isEmpty == false)
    }

    @Test func textValidationDescribesAnyValue() throws {
        let number = try ComplicationEditViewModel.validateText(42)
        let text = try ComplicationEditViewModel.validateText("Hello")
        #expect(number == "42")
        #expect(text == "Hello")
    }

    // MARK: - Option enums

    @Test func optionEnumsAreIdentifiedByRawValueAndLocalized() {
        for option in ComplicationEditViewModel.Column2Alignment.allCases {
            #expect(option.id == option.rawValue)
            #expect(!option.localizedName.isEmpty)
        }
        for option in ComplicationEditViewModel.GaugeType.allCases {
            #expect(option.id == option.rawValue)
            #expect(!option.localizedName.isEmpty)
        }
        for option in ComplicationEditViewModel.GaugeStyle.allCases {
            #expect(option.id == option.rawValue)
            #expect(!option.localizedName.isEmpty)
        }
        for option in ComplicationEditViewModel.RingType.allCases {
            #expect(option.id == option.rawValue)
            #expect(!option.localizedName.isEmpty)
        }
    }

    // MARK: - Helpers

    private func withWorld<T>(
        serverIds: [String] = ["server-1"],
        perform work: @MainActor (DatabaseQueue) throws -> T
    ) throws -> T {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }

        let previousDatabase = Current.database
        let previousServers = Current.servers

        let servers = FakeServerManager(initial: 0)
        for serverId in serverIds {
            servers.add(identifier: .init(rawValue: serverId), serverInfo: .fake())
        }

        Current.database = { database }
        Current.servers = servers

        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        return try work(database)
    }
}
