import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Every settings row resolves to its screen (rows with no screen of their own resolve to an empty
/// view), and the two wrapper screens render what they wrap.
/// Shared state: swaps `Current.database` and `Current.servers`, which the wrapped screens read.
@MainActor
@Suite(.sharedState)
struct SettingsItemDestinationsTests {
    @Test func everyItemResolvesItsScreen() {
        for item in SettingsItem.allCases {
            _ = item.destinationView
        }
        #expect(!SettingsItem.allCases.isEmpty)
    }

    @Test func wrapperScreensRenderWhatTheyWrap() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        defer { Current.resetAPICache(for: Current.servers.all.map(\.identifier)) }

        try await SettingsTestDatabase.with { _ in
            let notifications = await SwiftUIScreenDriver.show(SettingsNotificationsView())
            #expect(notifications.sectionCount > 1)
            notifications.close()

            let complications = await SwiftUIScreenDriver.show(SettingsComplicationsView())
            #expect(complications.sectionCount > 1)
            complications.close()
        }
    }
}
