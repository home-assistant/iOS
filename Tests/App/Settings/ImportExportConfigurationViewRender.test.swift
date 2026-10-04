import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the import/export screen out so SwiftUI evaluates the contents disclosure (each category with
/// its count), the never-exported list and the action buttons.
@MainActor
@Suite(.serialized)
struct ImportExportConfigurationViewRenderTests {
    @Test func rendersWithConfiguredAndEmptyCategories() throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let serverId = "import-export-render-server"
        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: serverId), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            let items = [
                MagicItem(id: "script.one", serverId: serverId, type: .script),
                MagicItem(id: "script.two", serverId: serverId, type: .script),
            ]
            try CustomWidget(id: "first", name: "First", items: items).insert(db)
            try CustomWidget(id: "second", name: "Second", items: items).insert(db)
        }
        Current.database = { database }

        let counts = try AppConfigurationTransfer.entryCounts(appSettings: AppSettingsSnapshot.capture())
        #expect(counts[.customWidgets] == 2)
        #expect((counts[.nfcTags] ?? 0) == 0)

        let controller = UIHostingController(rootView: NavigationView { ImportExportConfigurationView() })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(controller.sizeThatFits(in: CGSize(width: 390, height: 2400)).width > 0)

        window.isHidden = true
        window.rootViewController = nil
    }
}
