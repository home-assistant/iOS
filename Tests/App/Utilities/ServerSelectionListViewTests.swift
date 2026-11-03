@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders the compact server picker with and without the prompt explaining why it was opened, and
/// lists every server.
///
/// `.sharedState`: the picker lists `Current.servers`, which the tests swap.
@Suite(.sharedState)
@MainActor
struct ServerSelectionListViewTests {
    private final class Selection {
        var servers: [Server] = []
        var expanded = 0
    }

    private func show(
        prompt: ServerSelectPrompt?,
        selection: Selection
    ) async -> SwiftUIScreenDriver {
        await SwiftUIScreenDriver.show(
            ServerSelectionListView(
                prompt: prompt,
                selectAction: { selection.servers.append($0) },
                expandAction: { selection.expanded += 1 }
            ),
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
    }

    @Test(arguments: [nil, "/lovelace/0"])
    func listsEveryServerUnderThePrompt(_ link: String?) async {
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 2)
        Current.servers = servers
        defer { Current.servers = previousServers }

        let selection = Selection()
        let driver = await show(
            prompt: ServerSelectPrompt(message: L10n.Alerts.OpenUrlFromDeepLink.selectServer, link: link),
            selection: selection
        )
        defer { driver.close() }

        // The prompt row, then one row per server.
        await #expect(driver.waitUntil { driver.rows.count == 3 })
        #expect(driver.rowCount(inSection: 1) == servers.all.count)
        #expect(selection.servers.isEmpty)
    }

    @Test func listsServersWithoutAPrompt() async {
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 1)
        defer { Current.servers = previousServers }

        let driver = await show(prompt: nil, selection: Selection())
        defer { driver.close() }
        await #expect(driver.waitUntil { driver.rows.count == 1 })
    }
}
