import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: saving and deleting go through `Current.database`, and the view model resolves its
/// server through `Current.servers`.
@Suite(.sharedState)
@MainActor
struct ComplicationEditViewModelTests {
    private static let gaugeTemplate = ComplicationTemplate.GraphicCornerGaugeText

    @Test func parsesEverySavedSetting() throws {
        try withWorld { servers, _ in
            let config = WatchComplication(
                serverIdentifier: servers[1].identifier.rawValue,
                family: .graphicCorner,
                template: Self.gaugeTemplate,
                data: [
                    "column2alignment": ["column2alignment": "TRAILING"],
                    "gauge": [
                        "gauge": "{{ 0.5 }}",
                        "gauge_color": "#ff0000",
                        "gauge_type": "Closed",
                        "gauge_style": "Ring",
                    ],
                    "ring": ["ring_value": "{{ 0.2 }}", "ring_color": "#00ff00", "ring_type": "closed"],
                    "icon": ["icon": "lightbulb", "icon_color": "#0000ff"],
                    "textAreas": [
                        ComplicationTextAreas.Outer.slug: ["text": "Outer text", "color": "#123456"],
                    ],
                ],
                name: "Corner",
                isPublic: false
            )
            let viewModel = ComplicationEditViewModel(config: config, isNew: false)

            #expect(viewModel.name == "Corner")
            #expect(!viewModel.isPublic)
            #expect(viewModel.serverIdentifier == servers[1].identifier.rawValue)
            #expect(viewModel.server?.identifier == servers[1].identifier)
            #expect(viewModel.column2Alignment == .trailing)
            #expect(viewModel.gaugeTemplate == "{{ 0.5 }}")
            #expect(viewModel.gaugeType == .closed)
            #expect(viewModel.gaugeStyle == .ring)
            #expect(viewModel.ringTemplate == "{{ 0.2 }}")
            #expect(viewModel.ringType == .closed)
            #expect(viewModel.icon.name == "lightbulb")
            #expect(viewModel.textAreaValues[ComplicationTextAreas.Outer.slug]?.text == "Outer text")
            #expect(viewModel.textAreaValues.count == ComplicationTextAreas.allCases.count)
            #expect(viewModel.family == .graphicCorner)
            #expect(viewModel.hasGauge)
            #expect(!viewModel.isGaugeTypeForced)
        }
    }

    @Test func unknownServerFallsBackToTheFirstOne() throws {
        try withWorld { servers, _ in
            let config = WatchComplication(serverIdentifier: "missing", family: .modularSmall)
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)
            #expect(viewModel.serverIdentifier == servers[0].identifier.rawValue)
            #expect(viewModel.column2Alignment == .leading)
            #expect(viewModel.gaugeTemplate.isEmpty)

            viewModel.serverIdentifier = nil
            #expect(viewModel.server?.identifier == servers[0].identifier)
            viewModel.serverIdentifier = "also-missing"
            #expect(viewModel.server?.identifier == servers[0].identifier)
        }
    }

    @Test func forcedGaugeTemplatesPinTheGaugeType() throws {
        try withWorld { _, _ in
            let config = WatchComplication(
                family: .graphicCircular,
                template: .GraphicCircularOpenGaugeImage,
                data: ["gauge": ["gauge_type": "closed"]]
            )
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)
            #expect(viewModel.isGaugeTypeForced)
            #expect(viewModel.gaugeType == .open)

            viewModel.displayTemplate = .GraphicCircularClosedGaugeText
            viewModel.onDisplayTemplateChange()
            #expect(viewModel.gaugeType == .closed)

            // A template without a gauge leaves the type alone.
            viewModel.displayTemplate = .GraphicCircularImage
            viewModel.onDisplayTemplateChange()
            #expect(viewModel.gaugeType == .closed)
            #expect(!viewModel.hasGauge)
            #expect(viewModel.hasImage)
        }
    }

    @Test func validityRequiresEveryShownInput() throws {
        try withWorld { _, _ in
            let config = WatchComplication(family: .graphicCorner, template: Self.gaugeTemplate)
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)
            #expect(!viewModel.isValid)

            viewModel.gaugeTemplate = "{{ 0.5 }}"
            #expect(!viewModel.isValid)
            for area in viewModel.activeTextAreas {
                viewModel.textAreaValues[area.slug]?.text = "text"
            }
            #expect(viewModel.isValid)

            viewModel.displayTemplate = .CircularSmallRingText
            #expect(viewModel.hasRing)
            #expect(!viewModel.isValid)
            viewModel.ringTemplate = "{{ 0.1 }}"
            for area in viewModel.activeTextAreas {
                viewModel.textAreaValues[area.slug]?.text = "text"
            }
            #expect(viewModel.isValid)
        }
    }

    @Test func savePersistsTheEditedComplication() throws {
        try withWorld { servers, database in
            let column = ComplicationTemplate.ModularSmallColumnsText
            #expect(column.supportsColumn2Alignment)
            let family = ComplicationGroupMember.modularSmall
            let config = WatchComplication(family: family, template: column)
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)
            viewModel.name = "Saved"
            viewModel.isPublic = false
            viewModel.serverIdentifier = servers[1].identifier.rawValue
            viewModel.column2Alignment = .trailing
            for area in viewModel.activeTextAreas {
                viewModel.textAreaValues[area.slug]?.text = "value \(area.slug)"
            }

            var notified = false
            let observer = NotificationCenter.default.addObserver(
                forName: WatchComplication.didChangeNotification,
                object: nil,
                queue: nil
            ) { _ in notified = true }
            defer { NotificationCenter.default.removeObserver(observer) }

            viewModel.save()
            #expect(notified)

            // swiftformat:disable:next hoistTry
            let saved = try #require(try database.read { db in
                try WatchComplication.fetchOne(db, key: config.identifier)
            })
            #expect(saved.name == "Saved")
            #expect(!saved.isPublic)
            #expect(saved.serverIdentifier == servers[1].identifier.rawValue)
            let alignment = saved.Data["column2alignment"] as? [String: Any]
            #expect(alignment?["column2alignment"] as? String == "trailing")
            let areas = saved.Data["textAreas"] as? [String: [String: Any]]
            #expect(areas?.count == viewModel.activeTextAreas.count)

            // An empty name is stored as no name.
            viewModel.name = ""
            viewModel.save()
            let renamed = try database.read { db in try WatchComplication.fetchOne(db, key: config.identifier) }
            #expect(renamed?.name == nil)

            viewModel.delete()
            let deleted = try database.read { db in try WatchComplication.fetchOne(db, key: config.identifier) }
            #expect(deleted == nil)
        }
    }

    @Test func saveSerializesGaugeRingAndIcon() throws {
        try withWorld { _, database in
            let config = WatchComplication(family: .graphicCorner, template: .GraphicCornerGaugeImage)
            let viewModel = ComplicationEditViewModel(config: config, isNew: true)
            viewModel.gaugeTemplate = "{{ 0.4 }}"
            viewModel.gaugeColor = .red
            viewModel.gaugeStyle = .ring
            viewModel.icon = MaterialDesignIcons(named: "fan")
            viewModel.save()

            // swiftformat:disable:next hoistTry
            let saved = try #require(try database.read { db in
                try WatchComplication.fetchOne(db, key: config.identifier)
            })
            let gauge = saved.Data["gauge"] as? [String: Any]
            #expect(gauge?["gauge"] as? String == "{{ 0.4 }}")
            #expect(gauge?["gauge_style"] as? String == "ring")
            let icon = saved.Data["icon"] as? [String: Any]
            #expect(icon?["icon"] as? String == "fan")

            let ringConfig = WatchComplication(family: .circularSmall, template: .CircularSmallRingImage)
            let ringModel = ComplicationEditViewModel(config: ringConfig, isNew: true)
            ringModel.ringTemplate = "{{ 0.3 }}"
            ringModel.ringType = .closed
            ringModel.save()
            let ring = try database.read { db in try WatchComplication.fetchOne(db, key: ringConfig.identifier) }
            let ringData = ring?.Data["ring"] as? [String: Any]
            #expect(ringData?["ring_value"] as? String == "{{ 0.3 }}")
            #expect(ringData?["ring_type"] as? String == "closed")
        }
    }

    @Test func validatesPercentilesAndText() throws {
        // swiftformat:disable:next hoistTry
        #expect(try ComplicationEditViewModel.validatePercentile(0.5) == "0.5")
        // swiftformat:disable:next hoistTry
        #expect(try ComplicationEditViewModel.validatePercentile("0.25") == "0.25")
        #expect(throws: ComplicationEditViewModel.RenderValueError.self) {
            try ComplicationEditViewModel.validatePercentile(1.5)
        }
        #expect(throws: ComplicationEditViewModel.RenderValueError.self) {
            try ComplicationEditViewModel.validatePercentile("abc")
        }
        // swiftformat:disable:next hoistTry
        #expect(try ComplicationEditViewModel.validateText(42) == "42")

        let notNumber = ComplicationEditViewModel.RenderValueError.expectedFloat(value: "abc")
        #expect(notNumber.errorDescription?.contains("string") == true)
        let notNumberInt = ComplicationEditViewModel.RenderValueError.expectedFloat(value: [1])
        #expect(notNumberInt.errorDescription?.isEmpty == false)
        let outOfRange = ComplicationEditViewModel.RenderValueError.outOfRange(value: 3)
        #expect(outOfRange.errorDescription?.isEmpty == false)
    }

    @Test func optionsHaveLocalizedNames() {
        for option in ComplicationEditViewModel.Column2Alignment.allCases {
            #expect(!option.localizedName.isEmpty)
            #expect(option.id == option.rawValue)
        }
        for option in ComplicationEditViewModel.GaugeType.allCases {
            #expect(!option.localizedName.isEmpty)
            #expect(option.id == option.rawValue)
        }
        for option in ComplicationEditViewModel.GaugeStyle.allCases {
            #expect(!option.localizedName.isEmpty)
            #expect(option.id == option.rawValue)
        }
        for option in ComplicationEditViewModel.RingType.allCases {
            #expect(!option.localizedName.isEmpty)
            #expect(option.id == option.rawValue)
        }
    }

    private func withWorld(_ body: ([Server], DatabaseQueue) throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 2)
        Current.database = { database }
        Current.servers = servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        try body(servers.all, database)
    }
}
