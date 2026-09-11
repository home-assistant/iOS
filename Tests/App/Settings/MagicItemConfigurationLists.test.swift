import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The Watch, CarPlay, widget and app icon shortcut screens all list magic items the same way, so
/// each one is rendered here with every row kind it can hold.
@MainActor
struct MagicItemConfigurationListsTests {
    @Test func watchConfigurationListsEveryItemKind() throws {
        try withConfiguration { _ in
            let viewModel = WatchConfigurationViewModel()
            viewModel.watchConfig.items = Self.items
            assertLightDarkSnapshots(
                of: NavigationView { WatchConfigurationView(viewModel: viewModel) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @Test func watchFolderListsItsItems() throws {
        try withConfiguration { _ in
            let viewModel = WatchConfigurationViewModel()
            viewModel.watchConfig.items = Self.items
            assertLightDarkSnapshots(
                of: NavigationView { FolderDetailView(folderId: Self.folderId, viewModel: viewModel) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    /// The screen's artwork resamples differently from one OS version to the next, which no pixel
    /// tolerance survives, so this renders the list rather than comparing it. The rows it builds are
    /// compared in `MagicItemConfigurationRowTests` and in the folder screen below.
    @Test func carPlayConfigurationBuildsEveryItemKind() throws {
        try withConfiguration { database in
            try database.write { db in
                try CarPlayConfig(quickAccessItems: Self.items).insert(db, onConflict: .replace)
            }
            let viewModel = CarPlayConfigurationViewModel()
            viewModel.loadConfig()
            render(NavigationView { CarPlayConfigurationView(viewModel: viewModel) })
            #expect(viewModel.config.quickAccessItems.count == Self.items.count)
        }
    }

    @Test func carPlayFolderListsItsItems() throws {
        try withConfiguration { database in
            try database.write { db in
                try CarPlayConfig(quickAccessItems: Self.items).insert(db, onConflict: .replace)
            }
            let viewModel = CarPlayConfigurationViewModel()
            viewModel.loadConfig()
            assertLightDarkSnapshots(
                of: NavigationView { CarPlayFolderDetailView(folderId: Self.folderId, viewModel: viewModel) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @Test func widgetCreationListsItsItems() throws {
        try withConfiguration { _ in
            assertLightDarkSnapshots(
                of: NavigationView {
                    WidgetCreationView(
                        widget: CustomWidget(id: "widget-1", name: "Kitchen", items: Self.plainItems)
                    ) {}
                },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @Test func appIconShortcutsListsItsItems() throws {
        try withConfiguration { database in
            try database.write { db in
                try AppIconShortcutConfig(items: Self.plainItems).insert(db, onConflict: .replace)
            }
            let viewModel = AppIconShortcutsConfigurationViewModel()
            viewModel.loadConfig()
            assertLightDarkSnapshots(
                of: NavigationView { AppIconShortcutsConfigurationView(viewModel: viewModel) },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    private static let folderId = "folder-1"

    private static let plainItems: [MagicItem] = [
        .init(id: "light.kitchen", serverId: "1", type: .entity),
        .init(
            id: "prompt-1",
            serverId: "1",
            type: .assistPrompt,
            displayText: "Good night",
            assistPrompt: "Turn everything off downstairs"
        ),
    ]

    private static let items: [MagicItem] = plainItems + [
        .init(id: "complication-1", serverId: "1", type: .complication),
        .init(
            id: folderId,
            serverId: "",
            type: .folder,
            displayText: "Downstairs",
            items: plainItems
        ),
    ]

    /// Lays the view out in a key window, the way the snapshot helper does, so the list builds its
    /// rows without its pixels being compared.
    private func render(_ view: some View) {
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Current.date().addingTimeInterval(0.5))
    }

    /// Points `Current` at a fresh in-memory database and a provider that answers without a server,
    /// so every screen renders the items given to it rather than whatever the test database holds.
    private func withConfiguration(_ body: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousProvider = Current.magicItemProvider
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.magicItemProvider = previousProvider
        }

        Current.servers = FakeServerManager(initial: 1)
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }
        Current.magicItemProvider = { MagicItemConfigurationListsProvider() }

        try body(database)
    }
}

private final class MagicItemConfigurationListsProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(
            id: item.serverUniqueId,
            name: "Kitchen light",
            iconName: "mdi:lightbulb",
            contextSubtitle: "Home • Kitchen"
        )
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
