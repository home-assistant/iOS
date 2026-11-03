import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Shared state: loads, duplicates and deletes complications through `Current.database`.
@Suite(.sharedState)
@MainActor
struct ComplicationsRootViewModelTests {
    @Test func loadsConfigsWithTheirSubtitles() throws {
        try withComplications { _ in
            let viewModel = ComplicationsRootViewModel()
            viewModel.load()
            #expect(viewModel.configs.count == 4)
            #expect(viewModel.hasLegacy)
            #expect(viewModel.subtitles["known"] != nil)
            #expect(viewModel.subtitles["unknown"] == "Porch")
            #expect(viewModel.subtitles["template"] == L10n.Watch.Complications.Root.template)
            // An entity complication without an entity yet has no subtitle.
            #expect(viewModel.subtitles["empty"] == nil)
        }
    }

    @Test func duplicatesAndDeletes() throws {
        try withComplications { database in
            let viewModel = ComplicationsRootViewModel()
            viewModel.load()
            let original = try #require(viewModel.configs.first { $0.id == "template" })

            viewModel.duplicate(original)
            #expect(viewModel.configs.count == 5)
            let copy = try #require(viewModel.editing)
            #expect(copy.id != original.id)
            #expect(copy.customTextTemplate == original.customTextTemplate)

            viewModel.delete(at: IndexSet(integer: 0))
            #expect(viewModel.configs.count == 4)
            // swiftformat:disable:next hoistTry
            #expect(try database.read { db in try WatchComplicationConfig.fetchCount(db) } == 4)
        }
    }

    /// Without a paired watch the reload reports that it could not reach one (or why it failed).
    /// A duplicate that cannot be written leaves the list as it was.
    @Test func aDuplicateThatCannotBeSavedChangesNothing() throws {
        try withComplications { _ in
            let viewModel = ComplicationsRootViewModel()
            viewModel.load()
            let config = try #require(viewModel.configs.first)
            let previousDatabase = Current.database
            Current.database = { try! DatabaseQueue() }
            defer { Current.database = previousDatabase }
            let count = viewModel.configs.count
            viewModel.duplicate(config)
            #expect(viewModel.configs.count == count)
            #expect(viewModel.editing == nil)
        }
    }

    @Test func reloadReportsItsOutcome() async throws {
        let viewModel = ComplicationsRootViewModel()
        await viewModel.reload()
        #expect(!viewModel.isReloading)
        let alert = try #require(viewModel.reloadAlert)
        #expect(!alert.title.isEmpty)
    }

    private func withComplications(_ body: (DatabaseQueue) throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            try HAAppEntity(
                id: "server-sensor.outside",
                entityId: "sensor.outside",
                serverId: "server",
                domain: "sensor",
                name: "Outside",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
            try WatchComplicationConfig(
                id: "known",
                serverId: "server",
                kind: .entity,
                entityId: "sensor.outside",
                iconName: "thermometer",
                sortOrder: 0
            ).insert(db)
            try WatchComplicationConfig(
                id: "unknown",
                serverId: "server",
                kind: .entity,
                entityId: "sensor.porch",
                entityDisplayName: "Porch",
                sortOrder: 1
            ).insert(db)
            try WatchComplicationConfig(id: "empty", serverId: "server", kind: .entity, sortOrder: 2).insert(db)
            try WatchComplicationConfig(
                id: "template",
                serverId: "server",
                kind: .customTemplate,
                customTextTemplate: "{{ 1 }}",
                sortOrder: 3
            ).insert(db)
            try WatchComplication(family: .graphicCircular).insert(db)
        }
        let previous = Current.database
        Current.database = { database }
        defer { Current.database = previous }
        try body(database)
    }
}
