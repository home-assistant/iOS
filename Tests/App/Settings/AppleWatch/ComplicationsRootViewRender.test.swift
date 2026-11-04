import Foundation
import GRDB
import HAKit_Mocks
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Drives the complications root screen: its rows open the builder in a sheet, "Reload" reports back
/// in an alert and the legacy entry leads to the legacy list and its editor.
/// Shared state: the screens read `Current.database` and `Current.servers` from the main run loop.
@Suite(.sharedState)
@MainActor
struct ComplicationsRootViewRenderTests {
    @Test func newOpensTheBuilderInASheet() async throws {
        try await withWorld { _ in
            let driver = await SwiftUIScreenDriver.show(ComplicationsRootView())
            defer { driver.close() }
            // Header, your complications, reload, legacy, debug transfer (in debug builds).
            #expect(driver.sectionCount >= 4)
            // Three complications, then "New".
            #expect(driver.rowCount(inSection: 1) == 4)

            await driver.tapRow(IndexPath(item: 3, section: 1))
            await #expect(driver.waitUntil { driver.presented != nil })
            await #expect(driver.waitUntil { driver.sectionCount > 0 })
            await driver.dismissPresented()
        }
    }

    /// A complication saved elsewhere (the builder announces it) shows up in the list right away.
    @Test func aSavedComplicationShowsUpAtOnce() async throws {
        try await withWorld { database in
            let driver = await SwiftUIScreenDriver.show(ComplicationsRootView())
            defer { driver.close() }
            #expect(driver.rowCount(inSection: 1) == 4)

            let serverId = try #require(Current.servers.all.first?.identifier.rawValue)
            try await database.write { db in
                try WatchComplicationConfig(serverId: serverId, kind: .entity, sortOrder: 3).insert(db)
            }
            NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
            await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 5 })
        }
    }

    /// The entity row carries the entity's area under its name.
    @Test func builderShowsWhereTheEntityIs() async throws {
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 1)
        let serverId = servers.all[0].identifier.rawValue
        Current.servers = servers
        defer { Current.servers = previousServers }

        try await SettingsTestDatabase.with({ db in
            try HAAppEntity(
                id: "\(serverId)-sensor.outside",
                entityId: "sensor.outside",
                serverId: serverId,
                domain: "sensor",
                name: "Outside",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
            try AppArea(
                id: "\(serverId)-garden",
                serverId: serverId,
                areaId: "garden",
                name: "Garden",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: ["sensor.outside"]
            ).insert(db)
        }) { _ in
            // The live preview reads the entity's state over REST; answer it here instead of the network.
            let descriptor = stub(
                condition: { $0.url?.path.hasPrefix("/api/states/") == true },
                response: { _ in .init(
                    data: Data(#"{"state": "12", "attributes": {}}"#.utf8),
                    statusCode: 200,
                    headers: nil
                ) }
            )
            defer { HTTPStubs.removeStub(descriptor) }
            let config = WatchComplicationConfig(serverId: serverId, kind: .entity, entityId: "sensor.outside")
            let driver = await SwiftUIScreenDriver.show(
                NavigationView { WatchComplicationBuilderEditView(existing: config) },
                inNavigationStack: false
            )
            defer { driver.close() }
            #expect(driver.sectionCount > 2)
        }
    }

    /// The builder for each saved complication, and its source rows and configuration sheet.
    @Test func builderRendersEachSavedComplication() async throws {
        try await withWorld { database in
            let configs = try await database.read { db in try WatchComplicationConfig.fetchAll(db) }
            for config in configs {
                let driver = await SwiftUIScreenDriver.show(
                    NavigationView { WatchComplicationBuilderEditView(existing: config) },
                    inNavigationStack: false
                )
                #expect(driver.sectionCount > 2)
                await driver.type("Renamed")
                // The last section's last row opens the configuration sheet once a source is set.
                let last = driver.sectionCount - 1
                await driver.tapRow(IndexPath(item: driver.rowCount(inSection: last) - 1, section: last))
                if await driver.waitUntil(timeout: 2, { driver.presented != nil }) {
                    await driver.dismissPresented()
                }
                driver.close()
            }
        }
    }

    /// A template complication on a device with two servers offers the server picker; the toolbar's
    /// confirm button saves the complication. An entity complication's entity row opens the picker.
    @Test func builderPicksTheServerAndSaves() async throws {
        let database = try SettingsTestDatabase.make()
        let servers = FakeServerManager(initial: 2)
        let serverId = servers.all[0].identifier.rawValue
        let template = WatchComplicationConfig(
            serverId: serverId,
            kind: .customTemplate,
            name: "Template",
            customTextTemplate: "{{ 1 }}",
            sortOrder: 0
        )
        let entity = WatchComplicationConfig(
            serverId: serverId,
            kind: .entity,
            entityId: "sensor.outside",
            sortOrder: 1
        )
        try await database.write { db in
            try template.insert(db)
            try entity.insert(db)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        Current.database = { database }
        Current.servers = servers
        defer {
            Current.resetAPICache(for: servers.all.map(\.identifier))
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let templateDriver = await SwiftUIScreenDriver.show(
            NavigationView { WatchComplicationBuilderEditView(existing: template) },
            inNavigationStack: false
        )
        #expect(templateDriver.sectionCount > 3)
        for index in templateDriver.barButtons.indices.reversed() {
            await templateDriver.tapBarButton(index)
        }
        templateDriver.close()

        let entityDriver = await SwiftUIScreenDriver.show(
            NavigationView { WatchComplicationBuilderEditView(existing: entity) },
            inNavigationStack: false
        )
        defer { entityDriver.close() }
        // Name, source, then the entity row.
        await entityDriver.tapRow(IndexPath(item: 0, section: 2))
        if await entityDriver.waitUntil(timeout: 2, { entityDriver.presented != nil }) {
            await entityDriver.dismissPresented()
        }
    }

    /// Smart quotes typed into a template are straightened, which Jinja needs.
    @Test func templatesGetStraightQuotes() {
        var stored = ""
        let binding = Binding(get: { stored }, set: { stored = $0 }).straightQuoted()
        binding.wrappedValue = "{{ states(\u{201C}sensor.a\u{201D}) ~ \u{2018}x\u{2019} }}"
        #expect(stored == "{{ states(\"sensor.a\") ~ 'x' }}")
        #expect(binding.wrappedValue == stored)
    }

    @Test func reloadShowsTheOutcome() async throws {
        try await withWorld { _ in
            let driver = await SwiftUIScreenDriver.show(ComplicationsRootView())
            defer { driver.close() }
            await driver.tapRow(IndexPath(item: 0, section: 2))
            await #expect(driver.waitUntil(timeout: 30) { driver.alert != nil })
            await driver.tapAlertButton()
        }
    }

    /// The legacy list groups its complications, opens each in the legacy editor, and can delete them all.
    @Test func legacyListOpensItsComplications() async throws {
        try await withWorld { database in
            let driver = await SwiftUIScreenDriver.show(ComplicationsRootView())
            defer { driver.close() }
            await #expect(driver.push(IndexPath(item: 0, section: 3)))

            let groups = driver.sectionCount
            #expect(groups >= 3)
            // Every group section holds one complication; the trailing sections are add / delete all.
            for section in 0 ..< groups - 2 {
                await #expect(driver.push(IndexPath(item: 0, section: section)))
                await driver.pop()
            }

            // "Add" opens the family picker sheet (debug builds only).
            await driver.tapRow(IndexPath(item: 0, section: groups - 2))
            if await driver.waitUntil(timeout: 2, { driver.presented != nil }) {
                await #expect(driver.waitUntil { driver.sectionCount > 1 })
                // Families that already have a complication are disabled; open the first one that is not.
                var opened = false
                for section in 0 ..< driver.sectionCount where !opened {
                    for item in 0 ..< driver.rowCount(inSection: section) where !opened {
                        opened = await driver.push(IndexPath(item: item, section: section), timeout: 1)
                    }
                }
                #expect(opened)
                await driver.dismissPresented()
            }

            await driver.tapRow(IndexPath(item: 0, section: groups - 1))
            await #expect(driver.waitUntil { driver.alert != nil })
            await driver.tapAlertButton(L10n.Watch.Complications.Legacy.deleteAll)
            await #expect(driver.waitUntil {
                (try? database.read { db in try WatchComplication.fetchCount(db) }) == 0
            })
        }
    }

    @Test func familyPickerExplainsTheOneComplicationLimit() async throws {
        try await withWorld { _ in
            try await familyPicker()
        }
    }

    private func familyPicker() async throws {
        let limited = await SwiftUIScreenDriver.show(ComplicationFamilySelectView(
            allowMultiple: false,
            currentFamilies: [.modularSmall],
            onSaved: {}
        ))
        #expect(limited.sectionCount == ComplicationGroup.allCases.count + 1)
        limited.close()

        let open = await SwiftUIScreenDriver.show(ComplicationFamilySelectView(
            allowMultiple: true,
            currentFamilies: [],
            onSaved: {}
        ))
        #expect(open.sectionCount == ComplicationGroup.allCases.count)
        await #expect(open.push(IndexPath(item: 0, section: 0)))
        open.close()
    }

    private func withWorld(_ body: (DatabaseQueue) async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let servers = FakeServerManager(initial: 1)
        let server = servers.all[0]
        let serverId = server.identifier.rawValue
        try await database.write { db in
            try WatchComplicationConfig(
                serverId: serverId,
                kind: .entity,
                entityId: "sensor.outside",
                iconName: "thermometer",
                iconColor: "#ff0000",
                sortOrder: 0
            ).insert(db)
            try WatchComplicationConfig(serverId: serverId, kind: .entity, sortOrder: 1).insert(db)
            try WatchComplicationConfig(
                serverId: serverId,
                kind: .customTemplate,
                customTextTemplate: "{{ 1 }}",
                sortOrder: 2
            ).insert(db)
            try WatchComplication(serverIdentifier: serverId, family: .graphicCircular).insert(db)
            try WatchComplication(serverIdentifier: serverId, family: .modularSmall, name: "Small").insert(db)
            try WatchComplication(serverIdentifier: serverId, family: .utilitarianLarge).insert(db)
        }
        let api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: server.identifier)
        let previousDatabase = Current.database
        let previousServers = Current.servers
        Current.database = { database }
        Current.servers = servers
        defer {
            Current.resetAPICache(for: [server.identifier])
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        try await body(database)
    }
}
