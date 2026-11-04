import CarPlay
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Drives the CarPlay Settings tab through a fake navigator: the main server, layout, tabs and
/// troubleshooting screens it pushes, and what leaving each one commits.
@Suite(.sharedState)
@MainActor
struct CarPlayServerListTemplateTests {
    private typealias Rows = CarPlayTestRows

    private final class Harness {
        let servers: FakeServerManager
        let database: DatabaseQueue
        let navigator = FakeCarPlayNavigator()
        let viewModel = CarPlayServerListViewModel()
        let sut: CarPlayServersListTemplate

        init(servers: FakeServerManager, database: DatabaseQueue) {
            self.servers = servers
            self.database = database
            self.sut = CarPlayServersListTemplate(viewModel: viewModel)
            sut.navigatorOverride = navigator
        }

        func config() throws -> CarPlayConfig? {
            try database.read { db in try CarPlayConfig.fetchOne(db) }
        }

        func save(_ config: CarPlayConfig) throws {
            try database.write { db in try config.insert(db, onConflict: .replace) }
        }

        func pushed() -> CPListTemplate? {
            navigator.pushedTemplates.last as? CPListTemplate
        }
    }

    private func withHarness(serverCount: Int = 1, _ body: (Harness) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousDatabase = Current.database
        let previousPreferredServer = prefs.object(forKey: CarPlayPreferredServer.preferenceKey)
        let settings = PrivateSettingsStore()
        defer {
            Current.servers = previousServers
            Current.database = previousDatabase
            prefs.set(previousPreferredServer, forKey: CarPlayPreferredServer.preferenceKey)
            settings.restore()
        }
        prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        let servers = FakeServerManager(initial: serverCount)
        let database = try CarPlayTestDatabase.make()
        Current.servers = servers
        Current.database = { database }
        let harness = Harness(servers: servers, database: database)
        try await body(harness)
        harness.viewModel.removeServerObserver()
    }

    @Test func theSettingsTabListsEverySetting() async throws {
        try await withHarness { harness in
            #expect(harness.sut.template.tabTitle == L10n.CarPlay.Labels.Tab.settings)
            harness.sut.templateWillAppear(template: harness.sut.template)

            #expect(Rows.texts(harness.sut.template) == [
                L10n.CarPlay.Labels.Settings.MainServer.title,
                L10n.Carplay.Tab.QuickAccess.layout,
                L10n.CarPlay.Config.Tabs.title,
                L10n.CarPlay.Config.QuickAccess.ShowAddEditButtons.title,
                L10n.Assist.Settings.title,
                L10n.CarPlay.Labels.Settings.Troubleshooting.title,
            ])
            #expect(Rows.listItems(harness.sut.template).first?.detailText == harness.servers.all[0].info.name)
            harness.sut.templateWillDisappear(template: harness.sut.template)
            harness.sut.entitiesStateChange(serverId: "server", entities: .init(entitiesDictionary: [:]))
        }
    }

    @Test func pickingAnotherMainServerIsCommittedOnLeaving() async throws {
        try await withHarness(serverCount: 2) { harness in
            harness.sut.update()
            Rows.tap(Rows.row(harness.sut.template, L10n.CarPlay.Labels.Settings.MainServer.title))
            let selection = try #require(harness.pushed())

            let listed = await carPlayEventually { Rows.listItems(selection).count == 2 }
            #expect(listed)
            #expect(selection.sections.first?.header == L10n.CarPlay.Labels.selectServer)
            #expect(Rows.listItems(selection).first?.image != nil, "the current server is checked")

            let second = harness.servers.all[1]
            let row = Rows.listItems(selection)[1]
            var completed = false
            row.handler?(row) { completed = true }
            let settled = await carPlayEventually { completed }
            #expect(settled)
            #expect(harness.viewModel.isServerActive(second))

            harness.sut.templateWillDisappear(template: selection)
            #expect(CarPlayPreferredServer.id == second.identifier.rawValue)
        }
    }

    @Test func leavingServerSelectionUnchangedCommitsNothing() async throws {
        try await withHarness { harness in
            harness.viewModel.commitServerSelection()
            harness.sut.update()
            Rows.tap(Rows.row(harness.sut.template, L10n.CarPlay.Labels.Settings.MainServer.title))
            let selection = try #require(harness.pushed())
            harness.sut.templateWillDisappear(template: selection)

            #expect(CarPlayPreferredServer.id.isEmpty)
        }
    }

    @Test func serversWithoutAnyURLAreNotOffered() async throws {
        try await withHarness(serverCount: 0) { harness in
            let unreachable = Server.fake(update: { info in
                info.connection.set(address: nil, for: .external)
            })
            harness.servers.add(identifier: unreachable.identifier, serverInfo: unreachable.info)
            harness.sut.update()
            Rows.tap(Rows.row(harness.sut.template, L10n.CarPlay.Labels.Settings.MainServer.title))
            let selection = try #require(harness.pushed())

            let listed = await carPlayEventually { !Rows.listItems(selection).isEmpty }
            #expect(listed)
            #expect(Rows.texts(selection) == [L10n.CarPlay.Labels.noServersAvailable])
        }
    }

    @Test func theLayoutPickedIsSavedOnLeaving() async throws {
        try await withHarness { harness in
            harness.sut.update()
            Rows.tap(Rows.row(harness.sut.template, L10n.Carplay.Tab.QuickAccess.layout))
            let selection = try #require(harness.pushed())
            #expect(Rows.texts(selection) == CarPlayQuickAccessLayout.allCases.map(\.name))

            Rows.tap(Rows.row(selection, CarPlayQuickAccessLayout.list.name))
            #expect(harness.viewModel.isLayoutActive(.list))
            harness.sut.templateWillDisappear(template: selection)

            try #expect(harness.config()?.quickAccessLayout == .list)
        }
    }

    @Test func leavingTheLayoutUnchangedSavesNothing() async throws {
        try await withHarness { harness in
            harness.viewModel.commitLayoutSelection()
            harness.viewModel.beginLayoutSelection()
            harness.viewModel.commitLayoutSelection()

            try #expect(harness.config() == nil)
        }
    }

    @Test func tabsCanBeToggledButSettingsStays() async throws {
        try await withHarness { harness in
            let folder = MagicItem(id: "folder", serverId: "server", type: .folder, displayText: "Errands")
            let tabOnly = MagicItem(id: "tab-only", serverId: "server", type: .folder, displayText: "Tab only")
            try harness.save(CarPlayConfig(
                tabs: [.quickAccess, .folder(folderId: "tab-only"), .settings],
                quickAccessItems: [folder],
                tabFolders: [tabOnly]
            ))
            harness.sut.update()
            #expect(harness.viewModel.tabsSummary.contains("Tab only"))
            Rows.tap(Rows.row(harness.sut.template, L10n.CarPlay.Config.Tabs.title))
            let selection = try #require(harness.pushed())
            #expect(Rows.texts(selection).contains("Errands"))

            Rows.tap(Rows.row(selection, CarPlayTab.areas.name(folders: [])))
            Rows.tap(Rows.row(selection, "Tab only"))
            Rows.tap(Rows.row(selection, CarPlayTab.settings.name(folders: [])))
            harness.viewModel.setTab(.areas, active: true)
            harness.viewModel.setTab(.settings, active: false)
            harness.sut.templateWillDisappear(template: selection)

            let config = try harness.config()
            let saved = try #require(config)
            #expect(saved.tabs == [.quickAccess, .areas, .settings])
            #expect(saved.tabFolders?.isEmpty == true, "a tab-only folder goes with its tab")
        }
    }

    @Test func leavingTheTabsUnchangedSavesNothing() async throws {
        try await withHarness { harness in
            harness.viewModel.commitTabSelection()
            harness.viewModel.beginTabSelection()
            harness.viewModel.commitTabSelection()

            try #expect(harness.config() == nil)
        }
    }

    @Test func theAddEditRowToggles() async throws {
        try await withHarness { harness in
            harness.sut.update()
            #expect(harness.viewModel.showAddEditButtons)
            Rows.tap(Rows.row(harness.sut.template, L10n.CarPlay.Config.QuickAccess.ShowAddEditButtons.title))

            #expect(!harness.viewModel.showAddEditButtons)
            #expect(
                Rows.row(harness.sut.template, L10n.CarPlay.Config.QuickAccess.ShowAddEditButtons.title)?
                    .image == nil
            )
        }
    }

    @Test func assistSettingsOpenFromTheList() async throws {
        try await withHarness { harness in
            harness.sut.update()
            Rows.tap(Rows.row(harness.sut.template, L10n.Assist.Settings.title))

            #expect(harness.pushed()?.title == L10n.Assist.Settings.title)
        }
    }

    @Test func troubleshootingChangesTheAssistAudioPlayback() async throws {
        try await withHarness { harness in
            harness.sut.update()
            Rows.tap(Rows.row(harness.sut.template, L10n.CarPlay.Labels.Settings.Troubleshooting.title))
            let troubleshooting = try #require(harness.pushed())
            #expect(Rows.texts(troubleshooting).contains(
                L10n.CarPlay.Labels.Settings.Troubleshooting.ForceClose.title
            ))

            Rows.tap(Rows.row(troubleshooting, L10n.CarPlay.Labels.Settings.Troubleshooting.AssistAudio.title))
            let strategies = try #require(harness.pushed())
            #expect(Rows.texts(strategies) == CarPlayAssistTTSPlaybackStrategy.allCases.map(\.title))

            let other = try #require(CarPlayAssistTTSPlaybackStrategy.allCases.first {
                $0 != harness.viewModel.ttsPlaybackStrategy
            })
            Rows.tap(Rows.row(strategies, other.title))

            #expect(harness.viewModel.ttsPlaybackStrategy == other)
            #expect(harness.navigator.popCount == 1)
        }
    }

    @Test func losingEveryServerShowsTheNoServerAlertOnce() async throws {
        try await withHarness { harness in
            harness.viewModel.interfaceController = harness.navigator
            harness.viewModel.addServerObserver()
            let only = harness.servers.all[0]

            harness.servers.remove(identifier: only.identifier)
            harness.servers.notify()
            let alert = try #require(harness.navigator.presentedTemplates.last as? CPAlertTemplate)
            #expect(alert.titleVariants == [L10n.CarPlay.Labels.noServersAvailable])

            // While something is presented, a further change dismisses it rather than stacking alerts.
            harness.servers.notify()
            #expect(harness.navigator.dismissCount == 1)
            harness.sut.showNoServerAlert()
            harness.navigator.presentedTemplate = CPAlertTemplate(titleVariants: ["x"], actions: [])
            harness.sut.showNoServerAlert()
            #expect(harness.navigator.presentedTemplates.count == 2)

            // "Already added" only dismisses once a server is back.
            Rows.run(alert.actions.first)
            #expect(harness.navigator.dismissCount == 1)
            harness.servers.add(identifier: only.identifier, serverInfo: only.info)
            Rows.run(alert.actions.first)
            #expect(harness.navigator.dismissCount == 2)

            harness.servers.notify()
            #expect(CarPlayPreferredServer.id == only.identifier.rawValue)
        }
    }

    /// Every read and write fails against a database without tables; each falls back to defaults.
    @Test func aDatabaseThatFailsFallsBackToDefaults() async throws {
        try await withHarness { harness in
            let broken = try CarPlayTestDatabase.broken()
            Current.database = { broken }
            let viewModel = harness.viewModel

            #expect(viewModel.tabs == CarPlayConfig().tabs)
            #expect(viewModel.tabFolderItems.isEmpty)
            #expect(viewModel.quickAccessLayout == CarPlayConfig().resolvedQuickAccessLayout)
            #expect(viewModel.showAddEditButtons)
            viewModel.toggleShowAddEditButtons()
            viewModel.setLayout(.list)
            viewModel.commitLayoutSelection()
            viewModel.setTab(.domains, active: true)
            viewModel.commitTabSelection()
        }
    }
}
