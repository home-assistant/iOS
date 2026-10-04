import Foundation
import GRDB
@testable import Shared
import Testing

/// Serialized because every test swaps the global `Current.database`.
@Suite(.serialized)
struct WatchComplicationStorageTests {
    private func withDatabase(_ work: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try WatchComplicationTable().createIfNeeded(database: database)
        try WatchComplicationConfigTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try work(database)
    }

    private func storedIdentifiers() throws -> [String] {
        let complications: [WatchComplication] = try WatchComplication.all()
        return complications.map(\.identifier)
    }

    private func storedConfigIds() throws -> [String] {
        let configs: [WatchComplicationConfig] = try WatchComplicationConfig.all()
        return configs.map(\.id)
    }

    private func complication(_ identifier: String, server: String?, createdAt: TimeInterval) -> WatchComplication {
        WatchComplication(
            identifier: identifier,
            serverIdentifier: server,
            family: .modularSmall,
            data: ["textAreas": ["Center": ["text": identifier]]],
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }

    @Test func savedComplicationsAreReadBackOldestFirst() throws {
        try withDatabase { _ in
            try complication("second", server: "a", createdAt: 2000).save()
            try complication("first", server: "a", createdAt: 1000).save()
            try complication("third", server: "b", createdAt: 3000).save()

            let all: [WatchComplication] = try WatchComplication.all()
            #expect(all.map(\.identifier) == ["first", "second", "third"])
            let first = try #require(all.first)
            #expect(first.Template == .ModularSmallRingImage)
            let areas = first.Data["textAreas"] as? [String: [String: Any]]
            #expect(areas?["Center"]?["text"] as? String == "first")
        }
    }

    @Test func savingAgainUpdatesInPlace() throws {
        try withDatabase { _ in
            var item = complication("one", server: "a", createdAt: 1000)
            try item.save()
            item.name = "Renamed"
            try item.save()

            let all: [WatchComplication] = try WatchComplication.all()
            #expect(all.count == 1)
            #expect(all.first?.name == "Renamed")
        }
    }

    @Test func filtersByServer() throws {
        try withDatabase { _ in
            try complication("a1", server: "a", createdAt: 1000).save()
            try complication("a2", server: "a", createdAt: 2000).save()
            try complication("b1", server: "b", createdAt: 3000).save()

            let forA: [WatchComplication] = try WatchComplication.all(forServerIdentifier: "a")
            #expect(Set(forA.map(\.identifier)) == ["a1", "a2"])
            let stored1 = try WatchComplication.all(forServerIdentifier: "missing")
            #expect(stored1.isEmpty)
        }
    }

    @Test func deleteRemovesOnlyThatComplication() throws {
        try withDatabase { _ in
            let keep = complication("keep", server: "a", createdAt: 1000)
            let drop = complication("drop", server: "a", createdAt: 2000)
            try keep.save()
            try drop.save()

            try drop.delete()

            let stored2 = try storedIdentifiers()
            #expect(stored2 == ["keep"])
        }
    }

    @Test func replaceAllSwapsTheWholeTable() throws {
        try withDatabase { _ in
            try complication("old", server: "a", createdAt: 1000).save()

            try WatchComplication.replaceAll([
                complication("new1", server: "a", createdAt: 2000),
                complication("new2", server: "b", createdAt: 3000),
            ])

            let stored3 = try storedIdentifiers()
            #expect(stored3 == ["new1", "new2"])

            try WatchComplication.replaceAll([])
            let stored4 = try storedIdentifiers()
            #expect(stored4.isEmpty)
        }
    }

    @Test func deleteOrphansKeepsKnownServers() throws {
        try withDatabase { _ in
            try complication("known", server: "a", createdAt: 1000).save()
            try complication("orphan", server: "gone", createdAt: 2000).save()

            try WatchComplication.deleteOrphans(keepingServerIdentifiers: ["a"])

            let stored5 = try storedIdentifiers()
            #expect(stored5 == ["known"])
        }
    }

    @Test func configsAreReadBackInSortOrder() throws {
        try withDatabase { _ in
            try WatchComplicationConfig(id: "late", serverId: "a", sortOrder: 2).save()
            try WatchComplicationConfig(id: "early", serverId: "a", sortOrder: 1).save()

            let stored6 = try storedConfigIds()
            #expect(stored6 == ["early", "late"])
        }
    }

    @Test func configDeleteReplaceAndOrphans() throws {
        try withDatabase { _ in
            let first = WatchComplicationConfig(id: "first", serverId: "a", sortOrder: 0)
            try first.save()
            try WatchComplicationConfig(id: "second", serverId: "b", sortOrder: 1).save()

            try first.delete()
            let stored7 = try storedConfigIds()
            #expect(stored7 == ["second"])

            try WatchComplicationConfig.replaceAll([
                WatchComplicationConfig(id: "x", serverId: "a", sortOrder: 0),
                WatchComplicationConfig(id: "y", serverId: "gone", sortOrder: 1),
            ])
            let stored8 = try storedConfigIds()
            #expect(stored8 == ["x", "y"])

            try WatchComplicationConfig.deleteOrphans(keepingServerIds: ["a"])
            let stored9 = try storedConfigIds()
            #expect(stored9 == ["x"])
        }
    }

    @Test func configTitlesAreLocalized() {
        #expect(WatchComplicationConfig.GaugeStyle.open.title == L10n.Watch.Complications.GaugeStyle.open)
        #expect(WatchComplicationConfig.GaugeStyle.capacity.title == L10n.Watch.Complications.GaugeStyle.capacity)
        #expect(WatchComplicationConfig.Family.circular.title == L10n.Watch.Complications.Family.circular)
        #expect(WatchComplicationConfig.Family.rectangular.title == L10n.Watch.Complications.Family.rectangular)
        #expect(WatchComplicationConfig.Family.inline.title == L10n.Watch.Complications.Family.inline)
        #expect(WatchComplicationConfig.Family.corner.title == L10n.Watch.Complications.Family.corner)
    }
}
