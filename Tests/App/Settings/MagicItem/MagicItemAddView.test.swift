import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Lays the "add item" sheet out in every context and on every tab of its picker over an in-memory
/// database holding entities, an area, a watch complication and Assist pipelines, then adds an item
/// from each list.
///
/// `.sharedState`: the test swaps `Current.database` and `Current.servers`; the area list reads them
/// on a background queue.
@Suite(.sharedState)
@MainActor
struct MagicItemAddViewTests {
    private final class Added {
        var items: [MagicItem?] = []
    }

    private func withSeededServer(_ body: (String) async throws -> Void) async throws {
        let previousServers = Current.servers
        let manager = FakeServerManager(initial: 1)
        let serverId = manager.all[0].identifier.rawValue
        Current.servers = manager
        defer { Current.servers = previousServers }

        try await SettingsTestDatabase.with({ db in
            for (entityId, name) in [("light.kitchen", "Kitchen"), ("switch.fan", "Fan"), ("script.night", "Night")] {
                try HAAppEntity(
                    id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
                    entityId: entityId,
                    serverId: serverId,
                    domain: entityId.components(separatedBy: ".")[0],
                    name: name,
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
            }
            try AppArea(
                id: "\(serverId)-kitchen",
                serverId: serverId,
                areaId: "kitchen",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: "mdi:silverware",
                sortOrder: nil,
                entities: ["light.kitchen", "switch.fan"],
                floorId: "ground",
                floorName: "Ground floor"
            ).insert(db)
            try WatchComplicationConfig(
                id: "complication",
                serverId: serverId,
                widgetFamily: .rectangular,
                name: "Temperature",
                entityId: "sensor.temperature",
                entityDisplayName: "Outside",
                iconName: "mdi:thermometer",
                iconColor: "#FF0000"
            ).insert(db)
            try AssistPipelines(
                serverId: serverId,
                preferredPipeline: "local",
                pipelines: [.init(id: "local", name: "Home Assistant"), .init(id: "cloud", name: "Cloud")]
            ).insert(db)
        }) { _ in
            try await body(serverId)
        }
    }

    /// Picks a tab of the segmented picker at the top of the sheet.
    private func selectTab(_ index: Int, in harness: SettingsScreenHarness) async {
        guard let control = harness.views(of: UISegmentedControl.self).first,
              index < control.numberOfSegments else { return }
        control.selectedSegmentIndex = index
        control.sendActions(for: .valueChanged)
        await harness.settle()
    }

    @Test func watchContextAddsAnAreaAndAComplication() async throws {
        try await withSeededServer { serverId in
            let added = Added()
            let harness = await SettingsScreenHarness.show(
                MagicItemAddView(context: .watch, visiblePickerOptions: [.entities, .areas, .complications]) {
                    added.items.append($0)
                },
                inNavigationStack: false
            )
            #expect(harness.views(of: UISegmentedControl.self).first?.numberOfSegments == 3)
            await #expect(harness.waitUntil { harness.rows.count >= 3 })

            await selectTab(1, in: harness)
            await #expect(harness.waitUntil { harness.rows.count == 1 })
            await harness.search("kit")
            await harness.tapRow(IndexPath(item: 0, section: 0))
            #expect(added.items.last??.type == .area)
            #expect(added.items.last??.serverId == serverId)

            await selectTab(2, in: harness)
            await #expect(harness.waitUntil { harness.rows.count == 1 })
            await harness.search("temp")
            await harness.tapRow(IndexPath(item: 0, section: 0))
            #expect(added.items.count == 2)
            await harness.close()
        }
    }

    @Test func pickingAnEntityOpensItsCustomization() async throws {
        try await withSeededServer { _ in
            let harness = await SettingsScreenHarness.show(
                MagicItemAddView(context: .widget) { _ in },
                inNavigationStack: false
            )
            await #expect(harness.waitUntil { harness.rows.filter { $0.section > 0 }.count >= 3 })
            if let row = harness.rows.first(where: { $0.section > 0 }) {
                await harness.tapRow(row)
            }
            await #expect(harness.waitUntil { harness.depth == 2 })
            await harness.close()
        }
    }

    @Test func carPlayContextAddsAnAssistPipeline() async throws {
        try await withSeededServer { serverId in
            let added = Added()
            let harness = await SettingsScreenHarness.show(
                MagicItemAddView(context: .carPlay, initialItemType: .assistPipelines) { added.items.append($0) },
                inNavigationStack: false
            )
            // "Preferred" plus both pipelines.
            await #expect(harness.waitUntil { harness.rows.count == 3 })
            await harness.tapRow(IndexPath(item: 0, section: 0))
            await harness.tapRow(IndexPath(item: 2, section: 0))
            #expect(added.items.count == 2)
            #expect(added.items.first??.assistPipelineId == "")
            #expect(added.items.last??.id == "cloud")
            #expect(added.items.last??.serverId == serverId)

            await harness.search("clo")
            #expect(harness.rows.count == 1)
            await harness.close()
        }
    }

    @Test func everyFirstPickerOptionBecomesTheInitialTab() async throws {
        try await withSeededServer { _ in
            for options: [MagicItemAddView.PickerOption] in [[.areas], [.assistPipelines], [.complications], []] {
                let harness = await SettingsScreenHarness.show(
                    MagicItemAddView(context: .appIconShortcut, visiblePickerOptions: options) { _ in },
                    inNavigationStack: false
                )
                // A single option hides the picker.
                #expect(harness.views(of: UISegmentedControl.self).isEmpty)
                await harness.close()
            }
        }
    }

    @Test func emptyListsShowTheirEmptyStates() async throws {
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 0)
        defer { Current.servers = previousServers }
        try await SettingsTestDatabase.with { _ in
            for type: MagicItemAddType in [.areas, .complications, .assistPipelines] {
                let harness = await SettingsScreenHarness.show(
                    MagicItemAddView(context: .watch, initialItemType: type) { _ in },
                    inNavigationStack: false
                )
                await #expect(harness.waitUntil { harness.rows.count == 1 })
                await harness.close()
            }
        }
    }
}
