import CarPlay
import Foundation
import GRDB
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Drives the in-car "Add item" flow row by row through a fake navigator: server, category, areas,
/// domains, entities and Assist steps, the Back row, the info sheets and each way of committing.
@Suite(.sharedState)
@MainActor
struct CarPlayAddItemFlowTests {
    private typealias Rows = CarPlayTestRows

    private final class Harness {
        let servers: FakeServerManager
        let database: DatabaseQueue
        let navigator = FakeCarPlayNavigator()
        var finishCount = 0

        init(servers: FakeServerManager, database: DatabaseQueue) {
            self.servers = servers
            self.database = database
        }

        var server: Server { servers.all[0] }
        var serverId: String { server.identifier.rawValue }

        func makeFlow(destination: CarPlayAddItemViewModel.Destination = .quickAccess) -> CarPlayAddItemFlow {
            CarPlayAddItemFlow(
                interfaceController: navigator,
                viewModel: CarPlayAddItemViewModel(destination: destination)
            ) { [weak self] in
                self?.finishCount += 1
            }
        }

        func addEntity(_ entityId: String, name: String, serverId: String? = nil) throws {
            let serverId = serverId ?? self.serverId
            try database.write { db in
                try HAAppEntity(
                    id: "\(serverId)-\(entityId)",
                    entityId: entityId,
                    serverId: serverId,
                    domain: String(entityId.split(separator: ".")[0]),
                    name: name,
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
            }
        }

        func addArea(_ name: String, entities: Set<String>) throws {
            try database.write { db in
                try AppArea(
                    id: "\(serverId)-\(name)",
                    serverId: serverId,
                    areaId: name,
                    name: name,
                    aliases: [],
                    picture: nil,
                    icon: nil,
                    sortOrder: nil,
                    entities: entities
                ).insert(db)
            }
        }

        func config() throws -> CarPlayConfig? {
            try database.read { db in try CarPlayConfig.fetchOne(db) }
        }
    }

    private func withHarness(serverCount: Int = 1, _ body: (Harness) throws -> Void) throws {
        let previousServers = Current.servers
        let previousDatabase = Current.database
        defer {
            Current.servers = previousServers
            Current.database = previousDatabase
        }
        let servers = FakeServerManager(initial: serverCount)
        let database = try CarPlayTestDatabase.make()
        Current.servers = servers
        Current.database = { database }
        try body(Harness(servers: servers, database: database))
    }

    @Test func startingWithoutAnyServerFinishesAtOnce() throws {
        try withHarness(serverCount: 0) { harness in
            let flow = harness.makeFlow()
            flow.start()

            #expect(harness.finishCount == 1)
            #expect(harness.navigator.pushedTemplates.isEmpty)
        }
    }

    @Test func aSingleServerOpensOnItsCategories() throws {
        try withHarness { harness in
            let flow = harness.makeFlow()
            flow.start()

            #expect(harness.navigator.pushedTemplates.first === flow.template)
            let texts = Rows.texts(flow.template)
            #expect(texts.contains(L10n.CarPlay.Navigation.Tab.areas))
            #expect(texts.contains(L10n.CarPlay.Navigation.Tab.domains))
            #expect(texts.contains(L10n.Watch.Configuration.Folder.defaultName))
            #expect(!texts.contains(L10n.CarPlay.QuickAccess.AddItem.back))
            #expect(flow.template.sections.last?.header == harness.server.info.name)
        }
    }

    @Test func addingIntoAFolderLeavesOutTheFolderOption() throws {
        try withHarness { harness in
            let flow = harness.makeFlow(destination: .folder(folderId: "folder"))
            flow.start()

            #expect(!Rows.texts(flow.template).contains(L10n.Watch.Configuration.Folder.defaultName))
        }
    }

    @Test func severalServersStartOnServerSelectionAndBackReturnsThere() throws {
        try withHarness(serverCount: 2) { harness in
            let flow = harness.makeFlow()
            flow.start()

            let serverRows = Rows.listItems(flow.template)
            #expect(serverRows.count == 2)
            #expect(flow.template.sections.first?.header == L10n.CarPlay.Labels.selectServer)

            Rows.tap(serverRows.first)
            let back = Rows.row(flow.template, L10n.CarPlay.QuickAccess.AddItem.back)
            #expect(back != nil)
            #expect(Rows.texts(flow.template).contains(L10n.CarPlay.Navigation.Tab.areas))

            Rows.tap(back)
            #expect(Rows.listItems(flow.template).count == 2)
            #expect(harness.finishCount == 0)

            // A second tap on the stale Back row, with only the first step left, leaves the flow.
            Rows.tap(back)
            #expect(harness.navigator.popCount == 1)
            #expect(harness.finishCount == 1)
        }
    }

    @Test func folderAndAssistPromptRowsExplainThemselves() throws {
        try withHarness { harness in
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.Watch.Configuration.Folder.defaultName))
            let folderSheet = try #require(harness.navigator.presentedTemplates.last as? CPActionSheetTemplate)
            #expect(folderSheet.message == L10n.CarPlay.QuickAccess.AddItem.Folder.message)
            Rows.run(Rows.action(folderSheet, L10n.okLabel))
            #expect(harness.navigator.dismissCount == 1)

            guard #available(iOS 26.4, *) else { return }
            Rows.tap(Rows.row(flow.template, L10n.MagicItem.ItemType.AssistPrompt.title))
            let promptSheet = try #require(harness.navigator.presentedTemplates.last as? CPActionSheetTemplate)
            #expect(promptSheet.message == L10n.CarPlay.QuickAccess.AddItem.AssistPrompt.message)
            Rows.run(Rows.action(promptSheet, L10n.okLabel))
            #expect(harness.navigator.dismissCount == 2)
        }
    }

    @Test func emptyAreasDomainsAndAssistListsSaySo() throws {
        try withHarness { harness in
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.areas))
            #expect(Rows.texts(flow.template).contains(L10n.CarPlay.Labels.emptyAreaList))
            Rows.tap(Rows.row(flow.template, L10n.CarPlay.QuickAccess.AddItem.back))

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.domains))
            #expect(Rows.texts(flow.template).contains(L10n.CarPlay.Labels.emptyDomainList))
            Rows.tap(Rows.row(flow.template, L10n.CarPlay.QuickAccess.AddItem.back))

            guard #available(iOS 26.4, *) else { return }
            Rows.tap(Rows.row(flow.template, L10n.Widgets.Action.Name.assist))
            #expect(Rows.texts(flow.template).contains(L10n.CarPlay.Labels.emptyAssistList))
        }
    }

    @Test func anEntityPickedFromAnAreaIsSavedRequiringConfirmation() throws {
        try withHarness { harness in
            try harness.addEntity("light.kitchen", name: "Kitchen light")
            try harness.addEntity("sensor.temperature", name: "Temperature")
            try harness.addArea("Kitchen", entities: ["light.kitchen", "sensor.temperature"])
            try harness.addArea("Attic", entities: ["sensor.temperature"])
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.areas))
            #expect(Rows.texts(flow.template).contains("Kitchen"))
            #expect(!Rows.texts(flow.template).contains("Attic"))

            Rows.tap(Rows.row(flow.template, "Kitchen"))
            #expect(flow.template.sections.last?.header == "Kitchen")
            Rows.tap(Rows.row(flow.template, "Kitchen light"))

            let sheet = try #require(harness.navigator.presentedTemplates.last as? CPActionSheetTemplate)
            #expect(sheet.title == "Kitchen light")
            Rows.run(Rows.action(sheet, L10n.CarPlay.QuickAccess.AddItem.Confirmation.require))

            #expect(harness.navigator.dismissCount == 1)
            #expect(harness.navigator.popToRootCount == 1)
            #expect(harness.finishCount == 1)
            let saved = try #require(harness.config()?.quickAccessItems.first)
            #expect(saved.id == "light.kitchen")
            #expect(saved.customization?.requiresConfirmation == true)
        }
    }

    @Test func anEntityCanBeSavedRunningWithoutConfirmation() throws {
        try withHarness { harness in
            try harness.addEntity("switch.fan", name: "Fan")
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.domains))
            Rows.tap(Rows.listItems(flow.template).last)
            Rows.tap(Rows.row(flow.template, "Fan"))
            let sheet = harness.navigator.presentedTemplates.last
            Rows.run(Rows.action(sheet, L10n.CarPlay.QuickAccess.AddItem.Confirmation.noConfirmation))

            let saved = try #require(harness.config()?.quickAccessItems.first)
            #expect(saved.customization?.requiresConfirmation == false)
        }
    }

    @Test func cancellingTheConfirmationQuestionSavesNothing() throws {
        try withHarness { harness in
            try harness.addEntity("switch.fan", name: "Fan")
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.domains))
            Rows.tap(Rows.listItems(flow.template).last)
            Rows.tap(Rows.row(flow.template, "Fan"))
            Rows.run(Rows.action(harness.navigator.presentedTemplates.last, L10n.Alerts.Confirm.cancel))

            #expect(harness.navigator.dismissCount == 1)
            try #expect(harness.config() == nil)
            #expect(harness.finishCount == 0)
        }
    }

    /// Climate opens its own screen and locks always confirm, so neither asks the question.
    @Test func climateAndLockEntitiesAreSavedWithoutTheQuestion() throws {
        try withHarness { harness in
            try harness.addEntity("climate.hall", name: "Hall")
            try harness.addEntity("cover.garage", name: "Garage")
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.domains))
            // Covers sort first for quick garage access.
            #expect(Rows.texts(flow.template).dropFirst().first == Domain.cover.localizedDescription)
            Rows.tap(Rows.row(flow.template, Domain.climate.localizedDescription))
            Rows.tap(Rows.row(flow.template, "Hall"))

            #expect(harness.navigator.presentedTemplates.isEmpty)
            #expect(harness.navigator.dismissCount == 0)
            #expect(harness.navigator.popToRootCount == 1)
            let saved = try #require(harness.config()?.quickAccessItems.first)
            #expect(saved.id == "climate.hall")
            #expect(saved.customization?.requiresConfirmation == false)
        }
    }

    @Test func anEntityAddedToAMissingFolderIsNotSaved() throws {
        try withHarness { harness in
            try harness.addEntity("lock.front", name: "Front door")
            let flow = harness.makeFlow(destination: .folder(folderId: "missing"))
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.domains))
            Rows.tap(Rows.row(flow.template, Domain.lock.localizedDescription))
            Rows.tap(Rows.row(flow.template, "Front door"))

            #expect(harness.finishCount == 1)
            try #expect(harness.config() == nil)
        }
    }

    @Test func anAssistPipelineIsSavedFromTheAssistStep() throws {
        guard #available(iOS 26.4, *) else { return }
        try withHarness { harness in
            try harness.database.write { db in
                try AssistPipelines(
                    serverId: harness.serverId,
                    preferredPipeline: "voice",
                    pipelines: [Pipeline(id: "voice", name: "Voice", sttEngine: "stt.a", ttsEngine: "tts.a")]
                ).save(db)
            }
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.Widgets.Action.Name.assist))
            #expect(Rows.texts(flow.template).contains("Voice"))
            Rows.tap(Rows.row(flow.template, L10n.AppIntents.Assist.PreferredPipeline.title))

            #expect(harness.navigator.popToRootCount == 1)
            #expect(harness.finishCount == 1)
            let saved = try #require(harness.config()?.quickAccessItems.first)
            #expect(saved.type == .assistPipeline)
            #expect(saved.assistPipelineId == "")
        }
    }

    /// The list never exceeds CarPlay's cap, leaving room for the Back row.
    @Test func longListsAreTruncatedToFitTheBackRow() throws {
        try withHarness { harness in
            let count = Int(CPListTemplate.maximumItemCount) + 2
            for index in 0 ..< count {
                try harness.addEntity("switch.s\(index)", name: "Switch \(index)")
            }
            let flow = harness.makeFlow()
            flow.start()

            Rows.tap(Rows.row(flow.template, L10n.CarPlay.Navigation.Tab.domains))
            Rows.tap(Rows.listItems(flow.template).last)

            let entityRows = flow.template.sections.last?.items.count ?? 0
            #expect(entityRows == max(1, Int(CPListTemplate.maximumItemCount) - 1))
        }
    }
}
