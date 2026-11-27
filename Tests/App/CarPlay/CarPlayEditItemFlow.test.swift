import CarPlay
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Drives the in-car "Edit" flow through a fake navigator: one row per item, the action sheet each
/// item offers, and what deleting or changing the confirmation setting saves.
@Suite(.sharedState)
@MainActor
struct CarPlayEditItemFlowTests {
    private typealias Rows = CarPlayTestRows

    private final class Harness {
        let database: DatabaseQueue
        let navigator = FakeCarPlayNavigator()
        var finishCount = 0

        init(database: DatabaseQueue) {
            self.database = database
        }

        func save(_ config: CarPlayConfig) throws {
            try database.write { db in try config.insert(db, onConflict: .replace) }
        }

        func config() throws -> CarPlayConfig? {
            try database.read { db in try CarPlayConfig.fetchOne(db) }
        }

        func makeFlow(destination: CarPlayAddItemViewModel.Destination = .quickAccess) -> CarPlayEditItemFlow {
            CarPlayEditItemFlow(
                interfaceController: navigator,
                viewModel: CarPlayAddItemViewModel(destination: destination),
                itemDisplay: { item in (title: item.id, subtitle: item.serverId, image: UIImage()) },
                onFinish: { [weak self] in self?.finishCount += 1 }
            )
        }
    }

    private func withHarness(_ body: (Harness) throws -> Void) throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        let database = try CarPlayTestDatabase.make()
        Current.database = { database }
        try body(Harness(database: database))
    }

    private func item(_ id: String, _ type: MagicItem.ItemType, items: [MagicItem]? = nil) -> MagicItem {
        MagicItem(id: id, serverId: "server", type: type, items: items)
    }

    @Test func startingWithNothingToEditFinishesAtOnce() throws {
        try withHarness { harness in
            let flow = harness.makeFlow()
            flow.start()

            #expect(harness.finishCount == 1)
            #expect(harness.navigator.pushedTemplates.isEmpty)
        }
    }

    /// A flow CarPlay has no room to show is over before it starts, so its owner cleans up as after
    /// any other finish.
    @Test func startingOnAFullTemplateStackFinishesAtOnce() throws {
        try withHarness { harness in
            try harness.save(CarPlayConfig(quickAccessItems: [item("light.kitchen", .entity)]))
            for index in 0 ..< FakeCarPlayNavigator.maximumTemplateDepth {
                harness.navigator.pushTemplate(
                    CPListTemplate(title: "\(index)", sections: []),
                    animated: false,
                    completion: nil
                )
            }
            let flow = harness.makeFlow()
            flow.start()

            #expect(harness.finishCount == 1)
            #expect(!harness.navigator.pushedTemplates.contains { $0 === flow.template })
        }
    }

    /// Items whose tap runs a guarded action offer the confirmation choice; the rest only delete.
    @Test func eachItemOffersTheActionsThatApplyToIt() throws {
        try withHarness { harness in
            let items = [
                item("light.kitchen", .entity),
                item("unknown_domain.thing", .entity),
                item("lock.front", .entity),
                item("climate.hall", .entity),
                item("script.morning", .script),
                item("folder", .folder),
                item("pipeline", .assistPipeline),
            ]
            try harness.save(CarPlayConfig(quickAccessItems: items))
            let flow = harness.makeFlow()
            flow.start()

            #expect(harness.navigator.pushedTemplates.first === flow.template)
            #expect(Rows.texts(flow.template) == items.map(\.id))

            var offersConfirmation: [String: Bool] = [:]
            for row in Rows.listItems(flow.template) {
                Rows.tap(row)
                let sheet = try #require(harness.navigator.presentedTemplates.last as? CPActionSheetTemplate)
                #expect(sheet.title == row.text)
                #expect(Rows.action(sheet, L10n.delete) != nil)
                offersConfirmation[row.text ?? ""] =
                    Rows.action(sheet, L10n.CarPlay.QuickAccess.AddItem.Confirmation.require) != nil
            }
            #expect(offersConfirmation == [
                "light.kitchen": true,
                "unknown_domain.thing": true,
                "lock.front": false,
                "climate.hall": false,
                "script.morning": true,
                "folder": false,
                "pipeline": false,
            ])
        }
    }

    @Test func deletingAnItemSavesTheListWithoutIt() throws {
        try withHarness { harness in
            try harness.save(CarPlayConfig(quickAccessItems: [item("light.a", .entity), item("light.b", .entity)]))
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, "light.a"))
            Rows.run(Rows.action(harness.navigator.presentedTemplates.last, L10n.delete))

            try #expect(harness.config()?.quickAccessItems.map(\.id) == ["light.b"])
            #expect(harness.navigator.dismissCount == 1)
            #expect(harness.navigator.popToRootCount == 1)
            #expect(harness.finishCount == 1)
        }
    }

    @Test func theConfirmationSettingCanBeTurnedOnAndOff() throws {
        try withHarness { harness in
            try harness.save(CarPlayConfig(quickAccessItems: [item("switch.fan", .entity)]))
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, "switch.fan"))
            Rows.run(Rows.action(
                harness.navigator.presentedTemplates.last,
                L10n.CarPlay.QuickAccess.AddItem.Confirmation.require
            ))
            try #expect(harness.config()?.quickAccessItems.first?.customization?.requiresConfirmation == true)

            Rows.tap(Rows.row(flow.template, "switch.fan"))
            Rows.run(Rows.action(
                harness.navigator.presentedTemplates.last,
                L10n.CarPlay.QuickAccess.EditItem.Confirmation.noConfirmation
            ))
            try #expect(harness.config()?.quickAccessItems.first?.customization?.requiresConfirmation == false)
            #expect(harness.finishCount == 2)
        }
    }

    @Test func cancellingChangesNothing() throws {
        try withHarness { harness in
            try harness.save(CarPlayConfig(quickAccessItems: [item("lock.front", .entity)]))
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, "lock.front"))
            Rows.run(Rows.action(harness.navigator.presentedTemplates.last, L10n.Alerts.Confirm.cancel))

            #expect(harness.navigator.dismissCount == 1)
            #expect(harness.finishCount == 0)
            try #expect(harness.config()?.quickAccessItems.count == 1)
        }
    }

    @Test func aFolderDestinationEditsTheFolderItems() throws {
        try withHarness { harness in
            let folder = item("folder", .folder, items: [item("light.inside", .entity)])
            try harness.save(CarPlayConfig(quickAccessItems: [folder]))
            let flow = harness.makeFlow(destination: .folder(folderId: "folder"))
            flow.start()

            #expect(Rows.texts(flow.template) == ["light.inside"])
            Rows.tap(Rows.row(flow.template, "light.inside"))
            Rows.run(Rows.action(harness.navigator.presentedTemplates.last, L10n.delete))

            try #expect(harness.config()?.quickAccessItems.first?.items?.isEmpty == true)
        }
    }
}
