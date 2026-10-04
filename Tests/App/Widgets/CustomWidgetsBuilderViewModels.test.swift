import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The custom widgets list and the widget editor, run against an in-memory database.
@MainActor
@Suite(.serialized)
struct CustomWidgetsBuilderViewModelsTests {
    private static let serverId = "custom-widgets-server"

    @Test func listLoadsWidgetsSortedByName() throws {
        try withDatabase(widgets: ["Zeta", "Alpha", "Mid"]) { _ in
            let viewModel = WidgetBuilderViewModel()
            viewModel.loadWidgets()
            #expect(viewModel.widgets.map(\.name) == ["Alpha", "Mid", "Zeta"])
        }
    }

    @Test func listDeletesBySwipeByWidgetAndAllAtOnce() throws {
        try withDatabase(widgets: ["Alpha", "Beta", "Gamma"]) { database in
            let viewModel = WidgetBuilderViewModel()
            viewModel.loadWidgets()

            viewModel.deleteItem(at: IndexSet(integer: 0))
            #expect(viewModel.widgets.map(\.name) == ["Beta", "Gamma"])

            let gamma = try #require(viewModel.widgets.last)
            viewModel.deleteWidget(gamma)
            #expect(viewModel.widgets.map(\.name) == ["Beta"])

            viewModel.deleteAllWidgets()
            #expect(viewModel.widgets.isEmpty)
            let stored = try database.read { db in try CustomWidget.fetchCount(db) }
            #expect(stored == 0)
        }
    }

    @Test func reloadingShowsProgress() {
        let viewModel = WidgetBuilderViewModel()
        viewModel.reloadWidgets()
        #expect(viewModel.isLoading)
    }

    @Test func listScreenRendersStoredWidgets() throws {
        try withDatabase(widgets: ["Kitchen", "Office"]) { _ in
            let controller = UIHostingController(rootView: NavigationView { CustomWidgetsListView() })
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1600))
            window.rootViewController = controller
            window.isHidden = false
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            window.isHidden = true
            window.rootViewController = nil

            #expect(CustomWidgetsListView.settingsSearchEntries.count == 4)
        }
    }

    @Test func editorAddsUpdatesMovesAndRemovesItems() {
        let viewModel = WidgetCreationViewModel(widget: CustomWidget(id: "editor", name: "Editor", items: []))
        let first = MagicItem(id: "script.one", serverId: Self.serverId, type: .script)
        let second = MagicItem(id: "script.two", serverId: Self.serverId, type: .script)
        let third = MagicItem(id: "script.three", serverId: Self.serverId, type: .script)

        viewModel.addItem(first)
        viewModel.addItem(second)
        viewModel.addItem(third)
        #expect(viewModel.widget.items.map(\.id) == ["script.one", "script.two", "script.three"])

        var renamed = second
        renamed.displayText = "Renamed"
        viewModel.updateItem(renamed)
        #expect(viewModel.widget.items[1].displayText == "Renamed")
        #expect(viewModel.widget.items.count == 3)

        viewModel.moveItem(from: IndexSet(integer: 2), to: 0)
        #expect(viewModel.widget.items.map(\.id) == ["script.three", "script.one", "script.two"])

        viewModel.deleteItem(first)
        #expect(viewModel.widget.items.map(\.id) == ["script.three", "script.two"])

        viewModel.deleteItem(at: IndexSet(integer: 0))
        #expect(viewModel.widget.items.map(\.id) == ["script.two"])
    }

    @Test func editorRefusesToSaveWithoutANameOrItems() throws {
        try withDatabase(widgets: []) { database in
            let viewModel = WidgetCreationViewModel(widget: CustomWidget(id: "editor", name: "  ", items: []))
            viewModel.save()

            #expect(viewModel.showError)
            #expect(viewModel.errorMessage.isEmpty == false)
            #expect(viewModel.shouldDismiss == false)
            let stored = try database.read { db in try CustomWidget.fetchCount(db) }
            #expect(stored == 0)
        }
    }

    @Test func editorSavesAValidWidget() throws {
        try withDatabase(widgets: []) { database in
            let viewModel = WidgetCreationViewModel(widget: CustomWidget(
                id: "editor",
                name: "Evening",
                items: [MagicItem(id: "script.one", serverId: Self.serverId, type: .script)]
            ))
            viewModel.save()

            #expect(viewModel.shouldDismiss)
            #expect(viewModel.showError == false)
            let stored = try database.read { db in try CustomWidget.fetchAll(db) }
            #expect(stored.map(\.name) == ["Evening"])
        }
    }

    private func withDatabase(widgets names: [String], _ body: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            for name in names {
                try CustomWidget(
                    id: "widget-\(name)",
                    name: name,
                    items: [MagicItem(id: "script.\(name.lowercased())", serverId: Self.serverId, type: .script)]
                ).insert(db)
            }
        }
        Current.database = { database }

        try body(database)
    }
}
