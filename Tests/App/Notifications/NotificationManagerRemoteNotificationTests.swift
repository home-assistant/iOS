import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// What happens to a remote notification once it has arrived: its command runs, and one the app does not
/// know is reported as not handled rather than failing the delivery.
struct NotificationManagerRemoteNotificationTests {
    @MainActor
    @Test func anUnknownCommandFromLocalPushIsNotHandled() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let servers = FakeServerManager(initial: 0)
        let server = servers.addFake()
        Current.servers = servers

        let commands = RecordingCommandManager()
        let sut = NotificationManager()
        sut.commandManager = commands

        sut.localPushManager(
            LocalPushManager(server: server),
            didReceiveRemoteNotification: ["homeassistant": ["command": "no_such_command"]]
        )

        let handled = try #require(commands.payloads.first?["homeassistant"] as? [String: Any])
        #expect(handled["command"] as? String == "no_such_command")
    }

    /// Records what it is asked to handle and rejects it, the way an unknown command is rejected.
    private final class RecordingCommandManager: NotificationCommandManager {
        private(set) var payloads: [[AnyHashable: Any]] = []

        override func handle(_ payload: [AnyHashable: Any]) -> Promise<Void> {
            payloads.append(payload)
            return Promise(error: CommandError.unknownCommand)
        }
    }
}
