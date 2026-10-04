import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The complications root lists the saved configs with a context subtitle, flags whether any legacy
/// complication remains, and supports delete and duplicate.
@MainActor
@Suite(.serialized)
struct ComplicationsRootViewModelTests {
    @Test func loadListsConfigsWithSubtitlesAndDetectsLegacy() throws {
        try withWorld { _ in
            try WatchComplicationConfig(
                id: "entity",
                serverId: "server-1",
                entityId: "sensor.battery",
                entityDisplayName: "Battery",
                sortOrder: 0
            ).save()
            try WatchComplicationConfig(
                id: "entity-no-name",
                serverId: "server-1",
                entityId: "sensor.power",
                sortOrder: 1
            ).save()
            try WatchComplicationConfig(
                id: "template",
                serverId: "server-1",
                kind: .customTemplate,
                customTextTemplate: "{{ 1 }}",
                sortOrder: 2
            ).save()
            try WatchComplicationConfig(id: "unset", serverId: "server-1", sortOrder: 3).save()

            let viewModel = ComplicationsRootViewModel()
            viewModel.load()

            #expect(viewModel.configs.map(\.id) == ["entity", "entity-no-name", "template", "unset"])
            #expect(viewModel.subtitles["entity"] == "Battery")
            #expect(viewModel.subtitles["entity-no-name"] == "sensor.power")
            #expect(viewModel.subtitles["template"] == L10n.Watch.Complications.Root.template)
            #expect(viewModel.subtitles["unset"] == nil)
            #expect(!viewModel.hasLegacy)

            try WatchComplication(identifier: "legacy", family: .modularSmall).save()
            viewModel.load()
            #expect(viewModel.hasLegacy)
        }
    }

    @Test func deleteRemovesTheConfigsAtTheOffsets() throws {
        try withWorld { _ in
            try WatchComplicationConfig(id: "a", serverId: "server-1", sortOrder: 0).save()
            try WatchComplicationConfig(id: "b", serverId: "server-1", sortOrder: 1).save()
            try WatchComplicationConfig(id: "c", serverId: "server-1", sortOrder: 2).save()

            let viewModel = ComplicationsRootViewModel()
            viewModel.load()
            viewModel.delete(at: IndexSet([0, 2]))

            #expect(viewModel.configs.map(\.id) == ["b"])
            let stored = try WatchComplicationConfig.all().map(\.id)
            #expect(stored == ["b"])
        }
    }

    @Test func duplicateSavesACopyAtTheEndAndOpensIt() throws {
        try withWorld { _ in
            let original = WatchComplicationConfig(
                id: "original",
                serverId: "server-1",
                name: "Battery",
                entityId: "sensor.battery",
                sortOrder: 4
            )
            try original.save()

            let viewModel = ComplicationsRootViewModel()
            viewModel.load()
            viewModel.duplicate(original)

            #expect(viewModel.configs.count == 2)
            let copy = try #require(viewModel.editing)
            #expect(copy.id != "original")
            #expect(copy.name == "Battery")
            #expect(copy.entityId == "sensor.battery")
            #expect(copy.sortOrder == 5)
            #expect(viewModel.configs.last?.id == copy.id)
        }
    }

    @Test func rendersTheRootScreenWithConfigsAndLegacy() throws {
        try withWorld { _ in
            try WatchComplicationConfig(
                id: "entity",
                serverId: "server-1",
                entityId: "sensor.battery",
                iconName: "mdi:battery",
                iconColor: "#34C759"
            ).save()
            try WatchComplicationConfig(
                id: "template",
                serverId: "server-1",
                kind: .customTemplate,
                customTextTemplate: "Plain",
                sortOrder: 1
            ).save()
            try WatchComplication(identifier: "legacy", family: .graphicCircular).save()

            #expect(render(NavigationView { ComplicationsRootView() }))
            #expect(!ComplicationsRootView.settingsSearchEntries.isEmpty)
        }
    }

    @Test func rendersTheLegacyListGroupedByFamily() throws {
        try withWorld { _ in
            try WatchComplication(identifier: "graphic", family: .graphicCircular, name: "Ring").save()
            try WatchComplication(identifier: "modular", family: .modularLarge).save()

            let viewModel = ComplicationListViewModel()
            #expect(viewModel.complicationsByGroup[.graphic]?.map(\.identifier) == ["graphic"])
            #expect(viewModel.complicationsByGroup[.modular]?.map(\.identifier) == ["modular"])
            #expect(viewModel.complicationsByGroup[.utilitarian] == nil)
            #expect(viewModel.currentFamilies == [.graphicCircular, .modularLarge])

            #expect(render(NavigationView { ComplicationListView() }))
        }
    }

    @Test func deletingAllLegacyComplicationsEmptiesTheList() throws {
        try withWorld { _ in
            try WatchComplication(identifier: "one", family: .utilitarianLarge).save()
            try WatchComplication(identifier: "two", family: .extraLarge).save()

            let viewModel = ComplicationListViewModel()
            #expect(viewModel.currentFamilies.count == 2)

            viewModel.deleteAll()

            #expect(viewModel.complicationsByGroup.isEmpty)
            #expect(viewModel.currentFamilies.isEmpty)
            #expect(!viewModel.showError)
            let remaining = try WatchComplication.all()
            #expect(remaining.isEmpty)
        }
    }

    // MARK: - Helpers

    private func withWorld(_ work: (DatabaseQueue) throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: "server-1"), serverInfo: .fake())
        Current.database = { database }
        Current.servers = servers
        try work(database)
    }

    /// Deliberately never becomes the key window, so it can't leak into snapshot tests. Returns
    /// whether the hosted view was laid out in the window.
    private func render(_ view: some View) -> Bool {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = controller.view.window === window

        window.isHidden = true
        window.rootViewController = nil
        return laidOut
    }
}
