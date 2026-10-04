import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The Mac toolbar settings screen lists the entities pinned to the toolbar and removes them.
@MainActor
@Suite(.serialized)
struct MacToolbarSettingsViewTests {
    private static let serverId = "mac-toolbar-server"

    private static let items: [MagicItem] = [
        MagicItem(
            id: "light.kitchen",
            serverId: serverId,
            type: .entity,
            customization: .init(icon: "lightbulb"),
            displayText: "Kitchen"
        ),
        MagicItem(id: "script.goodnight", serverId: serverId, type: .script),
    ]

    @Test func loadsTheStoredItems() throws {
        try withConfig(items: Self.items) { _ in
            let viewModel = MacToolbarSettingsViewModel()
            #expect(viewModel.items.isEmpty)
            viewModel.load()
            #expect(viewModel.items.map(\.id) == ["light.kitchen", "script.goodnight"])
        }
    }

    @Test func loadsNothingWithoutAConfig() throws {
        try withConfig(items: nil) { _ in
            let viewModel = MacToolbarSettingsViewModel()
            viewModel.load()
            #expect(viewModel.items.isEmpty)
        }
    }

    @Test func removingAnItemStoresTheRestAndAnnouncesIt() throws {
        try withConfig(items: Self.items) { _ in
            let viewModel = MacToolbarSettingsViewModel()
            viewModel.load()

            let notifications = NotificationCounter()
            let observer = NotificationCenter.default.addObserver(
                forName: .macToolbarConfigDidChange,
                object: nil,
                queue: nil
            ) { _ in notifications.count += 1 }
            defer { NotificationCenter.default.removeObserver(observer) }

            viewModel.remove(Self.items[0])

            #expect(viewModel.items.map(\.id) == ["script.goodnight"])
            let stored = try MacToolbarConfig.config()
            #expect(stored?.items.map(\.id) == ["script.goodnight"])
            #expect(notifications.count == 1)
        }
    }

    @Test func rendersTheListAndTheEmptyState() throws {
        try withConfig(items: Self.items) { _ in
            render(MacToolbarSettingsView())
        }
        try withConfig(items: []) { _ in
            render(MacToolbarSettingsView())
        }
        #expect(MacToolbarSettingsView.settingsSearchEntries.count == 2)
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withConfig(items: [MagicItem]?, _ body: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        // Two servers, so each row names the server its entity belongs to.
        let servers = FakeServerManager(initial: 1)
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        if let items {
            try database.write { db in
                try MacToolbarConfig(items: items).insert(db, onConflict: .replace)
            }
        }
        Current.database = { database }

        try body(database)
    }
}

private final class NotificationCounter: @unchecked Sendable {
    var count = 0
}
