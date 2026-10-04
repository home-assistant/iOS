import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the entity picker out in each of its presentation modes against an in-memory database, so
/// SwiftUI evaluates the search field, the filter capsules and the grouped entity rows.
@MainActor
@Suite(.serialized)
struct EntityPickerRenderTests {
    private static let serverId = "entity-picker-server"
    private static let otherServerId = "entity-picker-other-server"

    @Test func listModeBuildsFiltersAndGroupedRows() throws {
        try withEntities {
            let size = render(EntityPicker(
                selectedServerId: Self.serverId,
                selectedEntity: .constant(nil),
                domainFilter: nil,
                mode: .list
            ))
            #expect(size.height > 0)
        }
    }

    @Test func inlineModeWithMultipleSelectionBuildsSectionHeaders() throws {
        try withEntities {
            var confirmed: [HAAppEntity] = []
            let size = render(EntityPicker(
                selectedServerId: Self.serverId,
                selectedEntity: .constant(nil),
                domainFilter: [.light, .switch],
                mode: .inline,
                initialSearchTerm: "",
                allowMultipleSelection: true,
                onMultipleSelectionConfirmed: { confirmed = $0 }
            ))
            #expect(size.height > 0)
            #expect(confirmed.isEmpty)
        }
    }

    @Test func inlineModeWithASearchTermUsesTheFuzzyIndex() throws {
        try withEntities {
            let size = render(EntityPicker(
                selectedServerId: nil,
                selectedEntity: .constant(nil),
                domainFilter: nil,
                mode: .inline,
                initialSearchTerm: "Kitchen"
            ))
            #expect(size.height > 0)
        }
    }

    @Test func buttonModeShowsThePlaceholderOrTheSelectedName() throws {
        try withEntities {
            let entity = Self.entities[0]
            let withSelection = render(EntityPicker(
                selectedServerId: Self.serverId,
                selectedEntity: .constant(entity),
                domainFilter: nil
            ))
            let withoutSelection = render(EntityPicker(
                selectedServerId: Self.serverId,
                selectedEntity: .constant(nil),
                domainFilter: nil
            ))
            #expect(withSelection.width > 0)
            #expect(withoutSelection.width > 0)
        }
    }

    private static let entities: [HAAppEntity] = [
        HAAppEntity(
            id: "\(serverId)-light.kitchen",
            entityId: "light.kitchen",
            serverId: serverId,
            domain: "light",
            name: "Kitchen Light",
            icon: nil,
            rawDeviceClass: nil
        ),
        HAAppEntity(
            id: "\(serverId)-switch.pump",
            entityId: "switch.pump",
            serverId: serverId,
            domain: "switch",
            name: "Pump",
            icon: "mdi:pump",
            rawDeviceClass: nil
        ),
        HAAppEntity(
            id: "\(serverId)-sensor.temperature",
            entityId: "sensor.temperature",
            serverId: serverId,
            domain: "sensor",
            name: "Temperature",
            icon: nil,
            rawDeviceClass: "temperature"
        ),
        HAAppEntity(
            id: "\(otherServerId)-light.office",
            entityId: "light.office",
            serverId: otherServerId,
            domain: "light",
            name: "Office Light",
            icon: nil,
            rawDeviceClass: nil
        ),
    ]

    /// Lays the view out in a visible (but never key) window, gives the picker's debounced filtering
    /// a moment to publish its groups, and lays it out again so the rows are built.
    @discardableResult
    private func render(_ view: some View) -> CGSize {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1200))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let size = controller.sizeThatFits(in: CGSize(width: 390, height: 1200))

        window.isHidden = true
        window.rootViewController = nil
        return size
    }

    private func withEntities(_ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        servers.add(identifier: .init(rawValue: Self.otherServerId), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            for entity in Self.entities {
                try entity.insert(db)
            }
            try AppArea(
                id: "\(Self.serverId)-kitchen",
                serverId: Self.serverId,
                areaId: "kitchen",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: "mdi:fridge",
                sortOrder: 1,
                entities: ["light.kitchen"]
            ).insert(db)
            try AppArea(
                id: "\(Self.serverId)-garden",
                serverId: Self.serverId,
                areaId: "garden",
                name: "Garden",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: 2,
                entities: ["switch.pump"]
            ).insert(db)
        }
        Current.database = { database }

        try body()
    }
}
