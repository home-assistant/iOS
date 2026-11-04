import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The sheet that picks which custom widget an entity is added to: the widgets it lists, sorted by
/// name, and the empty state it shows when there are none yet.
@Suite(.sharedState)
@MainActor
struct WidgetSelectionViewTests {
    private func withWidgets(_ widgets: [CustomWidget], _ body: () throws -> Void) throws {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            for widget in widgets {
                try widget.insert(db)
            }
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }
        try body()
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    private let widgets = [
        CustomWidget(id: "b", name: "Bedroom", items: [MagicItem(id: "light.bed", serverId: "s", type: .entity)]),
        CustomWidget(id: "a", name: "Attic", items: []),
    ]

    @Test func loadsTheStoredWidgetsSortedByName() throws {
        try withWidgets(widgets) {
            let viewModel = WidgetSelectionViewModel(entityId: "light.kitchen", serverId: "server")
            viewModel.loadWidgets()
            #expect(viewModel.widgets.map(\.name) == ["Attic", "Bedroom"])
            #expect(viewModel.entityId == "light.kitchen")
            #expect(viewModel.serverId == "server")
        }
    }

    @Test func loadsNothingWithoutWidgets() throws {
        try withWidgets([]) {
            let viewModel = WidgetSelectionViewModel(entityId: "light.kitchen", serverId: "server")
            viewModel.loadWidgets()
            #expect(viewModel.widgets.isEmpty)
        }
    }

    @Test(arguments: [false, true])
    func rendersTheListOrTheEmptyState(hasWidgets: Bool) throws {
        try withWidgets(hasWidgets ? widgets : []) {
            render(WidgetSelectionView(entityId: "light.kitchen", serverId: "server") { _ in })
        }
    }
}
