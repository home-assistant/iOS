import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the "add item" sheet out on each of its tabs (entities, areas, Assist pipelines and watch
/// complications) against an in-memory database holding something for each, so SwiftUI evaluates
/// the segmented picker and every list it switches between.
@MainActor
@Suite(.serialized)
struct MagicItemAddViewRenderTests {
    private static let serverId = "magic-item-add-server"

    private static let allOptions: [MagicItemAddView.PickerOption] = [
        .entities,
        .areas,
        .assistPipelines,
        .complications,
    ]

    @Test func entitiesTabForTheWatch() throws {
        try withDatabase {
            var added: [MagicItem?] = []
            render(MagicItemAddView(
                context: .watch,
                initialItemType: .entities,
                visiblePickerOptions: Self.allOptions,
                allowMultipleSelection: true
            ) { added.append($0) })
            #expect(added.isEmpty)
        }
    }

    @Test func entitiesTabWithTheDefaultOptions() throws {
        try withDatabase {
            render(MagicItemAddView(context: .carPlay) { _ in })
            render(MagicItemAddView(context: .widget) { _ in })
        }
    }

    @Test func areasTab() throws {
        try withDatabase {
            render(MagicItemAddView(context: .watch, initialItemType: .areas, visiblePickerOptions: Self.allOptions) { _ in
            })
        }
    }

    @Test func assistPipelinesTab() throws {
        try withDatabase {
            render(MagicItemAddView(
                context: .appIconShortcut,
                initialItemType: .assistPipelines,
                visiblePickerOptions: Self.allOptions
            ) { _ in })
        }
    }

    @Test func complicationsTab() throws {
        try withDatabase {
            render(MagicItemAddView(
                context: .watch,
                initialItemType: .complications,
                visiblePickerOptions: Self.allOptions
            ) { _ in })
        }
    }

    @Test func listsRenderOnTheirOwn() throws {
        try withDatabase {
            render(NavigationView { AreaMagicItemAddList { _ in } })
            render(NavigationView { AssistPipelineAddList { _ in } })
            render(NavigationView { ComplicationMagicItemAddList { _ in } })
        }
    }

    @Test func emptyListsShowTheirEmptyStates() throws {
        try withDatabase(seeded: false) {
            render(NavigationView { AreaMagicItemAddList { _ in } })
            render(NavigationView { ComplicationMagicItemAddList { _ in } })
        }
    }

    @Test func viewModelStartsWithoutAServer() {
        let viewModel = MagicItemAddViewModel(selectedItemType: .complications)
        #expect(viewModel.selectedItemType == .complications)
        #expect(viewModel.selectedServerId == nil)
    }

    /// Lays the view out in a visible (but never key) window, then lets the lists that load on a
    /// background queue or behind a debounce land before laying it out again.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1200))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withDatabase(seeded: Bool = true, _ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        // The Assist list asks the servers for their pipelines when none are stored, so they are
        // always stored here to keep the test off the network.
        try database.write { db in
            try AssistPipelines(
                serverId: Self.serverId,
                preferredPipeline: "home",
                pipelines: [Pipeline(id: "home", name: "Home"), Pipeline(id: "office", name: "Office")]
            ).insert(db)
        }
        if seeded {
            try database.write { db in
                try HAAppEntity(
                    id: "\(Self.serverId)-light.kitchen",
                    entityId: "light.kitchen",
                    serverId: Self.serverId,
                    domain: "light",
                    name: "Kitchen Light",
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
                try HAAppEntity(
                    id: "\(Self.serverId)-script.goodnight",
                    entityId: "script.goodnight",
                    serverId: Self.serverId,
                    domain: "script",
                    name: "Good Night",
                    icon: "mdi:weather-night",
                    rawDeviceClass: nil
                ).insert(db)
                try AppArea(
                    id: "\(Self.serverId)-kitchen",
                    serverId: Self.serverId,
                    areaId: "kitchen",
                    name: "Kitchen",
                    aliases: [],
                    picture: nil,
                    icon: "mdi:fridge",
                    sortOrder: 1,
                    entities: ["light.kitchen"],
                    floorId: "ground",
                    floorName: "Ground floor"
                ).insert(db)
                try WatchComplicationConfig(
                    id: "rectangular-config",
                    serverId: Self.serverId,
                    widgetFamily: .rectangular,
                    name: "Temperature",
                    entityId: "sensor.temperature",
                    entityDisplayName: "Living room temperature",
                    iconName: "mdi:thermometer",
                    iconColor: "#FF0000"
                ).insert(db)
                try WatchComplicationConfig(
                    id: "circular-config",
                    serverId: Self.serverId,
                    widgetFamily: .circular,
                    entityId: "sensor.humidity"
                ).insert(db)
            }
        }
        Current.database = { database }

        try body()
    }
}
