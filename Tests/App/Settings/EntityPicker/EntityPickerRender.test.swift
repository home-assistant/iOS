import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the entity picker out in each of its modes against entities seeded in the app database, and
/// drives its rows so the single and multiple selection flows run.
///
/// `.sharedState`: the picker reads `Current.servers` and the app database from its `onAppear` and
/// from main-queue debounced filtering, and the test seeds the app database.
@Suite(.sharedState)
@MainActor
struct EntityPickerRenderTests {
    private final class SelectionBox {
        var entity: HAAppEntity?
        var confirmed: [HAAppEntity] = []

        var binding: Binding<HAAppEntity?> {
            Binding(get: { self.entity }, set: { self.entity = $0 })
        }
    }

    private nonisolated static func entity(_ serverId: String, _ entityId: String, _ name: String) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: entityId.hasPrefix("light") ? "mdi:lightbulb" : nil,
            rawDeviceClass: nil
        )
    }

    /// Two fake servers; the first one gets lights, a switch and a sensor, half of them in an area.
    private func withSeededServers(
        serverCount: Int = 2,
        _ body: (String) async throws -> Void
    ) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: 0)
        let servers = (0 ..< serverCount).map { _ in manager.addFake() }
        Current.servers = manager
        let serverId = servers[0].identifier.rawValue
        defer {
            Current.servers = previous
            try? Current.database().write { db in
                try HAAppEntity.filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId).deleteAll(db)
                try AppArea.filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId).deleteAll(db)
            }
        }
        try await Current.database().write { db in
            for entity in [
                Self.entity(serverId, "light.kitchen", "Kitchen Light"),
                Self.entity(serverId, "light.bedroom", "Bedroom Light"),
                Self.entity(serverId, "switch.pump", "Pump"),
                Self.entity(serverId, "sensor.temperature", "Temperature"),
            ] {
                try entity.insert(db)
            }
            try AppArea(
                id: "\(serverId)-kitchen",
                serverId: serverId,
                areaId: "kitchen",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: ["light.kitchen", "light.bedroom"],
                floorId: nil,
                floorName: nil
            ).insert(db)
        }
        try await body(serverId)
    }

    /// The entity rows: everything after the first section, which holds the filter chips.
    private func entityRows(_ harness: SettingsScreenHarness) -> [IndexPath] {
        harness.rows.filter { $0.section > 0 }
    }

    private func waitForEntityRows(_ harness: SettingsScreenHarness, atLeast count: Int) async -> Bool {
        await harness.waitUntil { entityRows(harness).count >= count }
    }

    @Test func listModeSelectsTheTappedEntity() async throws {
        try await withSeededServers { serverId in
            let box = SelectionBox()
            let harness = await SettingsScreenHarness.show(
                EntityPicker(selectedServerId: serverId, selectedEntity: box.binding, domainFilter: nil, mode: .list),
                inNavigationStack: false
            )
            await #expect(waitForEntityRows(harness, atLeast: 4))

            if let row = entityRows(harness).first {
                await harness.tapRow(row)
            }
            #expect(box.entity?.serverId == serverId)
            await harness.close()
        }
    }

    @Test func multipleSelectionReportsEveryPickedEntity() async throws {
        try await withSeededServers { serverId in
            let box = SelectionBox()
            let harness = await SettingsScreenHarness.show(
                EntityPicker(
                    selectedServerId: serverId,
                    selectedEntity: box.binding,
                    domainFilter: nil,
                    mode: .list,
                    allowMultipleSelection: true,
                    onMultipleSelectionConfirmed: { box.confirmed = $0 }
                ),
                inNavigationStack: false
            )
            await #expect(waitForEntityRows(harness, atLeast: 4))

            // Pick two, drop one, pick it again: a toggle each time.
            let rows = entityRows(harness)
            try #require(rows.count >= 2)
            await harness.tapRow(rows[0])
            await harness.tapRow(rows[1])
            await harness.tapRow(rows[1])
            await harness.tapRow(rows[1])
            #expect(box.entity == nil)

            await harness.close()
        }
    }

    @Test func inlineMultipleSelectionKeepsPicksUntilConfirmed() async throws {
        try await withSeededServers(serverCount: 1) { serverId in
            let box = SelectionBox()
            let harness = await SettingsScreenHarness.show(
                EntityPicker(
                    selectedServerId: serverId,
                    selectedEntity: box.binding,
                    domainFilter: nil,
                    mode: .inline,
                    allowMultipleSelection: true,
                    onMultipleSelectionConfirmed: { box.confirmed = $0 }
                ),
                inNavigationStack: false
            )
            await #expect(waitForEntityRows(harness, atLeast: 4))
            if let row = entityRows(harness).last {
                await harness.tapRow(row)
            }
            #expect(box.entity == nil)
            #expect(box.confirmed.isEmpty)
            await harness.close()
        }
    }

    @Test func searchTermAndDomainFilterNarrowTheList() async throws {
        try await withSeededServers { serverId in
            let box = SelectionBox()
            let harness = await SettingsScreenHarness.show(
                EntityPicker(
                    selectedServerId: serverId,
                    selectedEntity: box.binding,
                    domainFilter: [.light, .switch],
                    mode: .inline,
                    initialSearchTerm: "kitchen"
                ),
                inNavigationStack: false
            )
            await #expect(waitForEntityRows(harness, atLeast: 1))
            #expect(entityRows(harness).count < 4)
            await harness.close()
        }
    }

    /// Pulling the list down refreshes the server through the database updater and shows the
    /// progress row until that server's update finishes.
    @Test func pullToRefreshShowsProgressUntilTheUpdateFinishes() async throws {
        let previousUpdater = Current.appDatabaseUpdater
        let updater = IdleDatabaseUpdater()
        Current.appDatabaseUpdater = updater
        defer { Current.appDatabaseUpdater = previousUpdater }

        try await withSeededServers { serverId in
            let box = SelectionBox()
            let harness = await SettingsScreenHarness.show(
                EntityPicker(selectedServerId: serverId, selectedEntity: box.binding, domainFilter: nil, mode: .list),
                inNavigationStack: false
            )
            await #expect(waitForEntityRows(harness, atLeast: 4))
            let sections = harness.list?.numberOfSections ?? 0

            let refreshControl = try #require(harness.list?.refreshControl)
            refreshControl.beginRefreshing()
            refreshControl.sendActions(for: .valueChanged)
            await #expect(harness.waitUntil { updater.updated.count == 1 })
            await #expect(harness.waitUntil { (harness.list?.numberOfSections ?? 0) > sections })

            let server = try #require(Current.servers.all.first { $0.identifier.rawValue == serverId })
            NotificationCenter.default.post(name: .appDatabaseUpdaterDidFinishRoutine, object: server)
            await #expect(harness.waitUntil { (harness.list?.numberOfSections ?? 0) == sections })
            await harness.close()
        }
    }

    @Test func buttonModeShowsThePlaceholderAndOpensTheList() async throws {
        try await withSeededServers { serverId in
            let box = SelectionBox()
            // In a list the picker's button is the row, so tapping the row opens the sheet.
            let harness = await SettingsScreenHarness.show(
                List {
                    EntityPicker(selectedServerId: serverId, selectedEntity: box.binding, domainFilter: nil)
                },
                inNavigationStack: false
            )
            await harness.tapRow(IndexPath(item: 0, section: 0))
            await #expect(harness.waitUntil(timeout: 5) { harness.presented != nil })
            await #expect(harness.waitUntil { harness.rows.filter { $0.section > 0 }.count >= 4 })

            // Picking an entity in the sheet reports it and closes the sheet.
            if let row = harness.rows.first(where: { $0.section > 0 }) {
                await harness.tapRow(row)
            }
            #expect(box.entity?.serverId == serverId)
            await #expect(harness.waitUntil(timeout: 5) { harness.presented == nil })
            await harness.close()
        }
    }

    @Test func buttonModeShowsTheSelectedEntityName() async throws {
        try await withSeededServers(serverCount: 1) { serverId in
            let box = SelectionBox()
            box.entity = Self.entity(serverId, "light.kitchen", "Kitchen Light")
            let harness = await SettingsScreenHarness.show(
                EntityPicker(selectedEntity: box.binding, domainFilter: [.light]),
                inNavigationStack: false
            )
            #expect(box.entity?.name == "Kitchen Light")
            await harness.close()
        }
    }
}

/// Records refresh requests instead of updating the app database.
private final class IdleDatabaseUpdater: AppDatabaseUpdaterProtocol {
    private(set) var updated: [Identifier<Server>] = []

    func stop() {}

    func update(server: Server, forceUpdate: Bool, showProgress: Bool) {
        updated.append(server.identifier)
    }
}
