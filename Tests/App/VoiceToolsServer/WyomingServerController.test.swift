import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
struct WyomingServerControllerTests {
    private func withTestDatabase(_ work: () throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }
        try work()
    }

    @Test func staysStoppedWhileTheUserHasNotTurnedItOn() throws {
        try withTestDatabase {
            let controller = WyomingServerController()

            controller.applyConfiguration(VoiceToolsServerConfiguration(isEnabled: false))

            #expect(controller.state == .stopped)
        }
    }

    /// On iOS the process is suspended shortly after it leaves the screen and the socket dies with
    /// it, so the listener is taken down deliberately instead of advertising a service that answers
    /// nothing.
    @Test func stopsWhenTheAppLeavesTheScreen() throws {
        try withTestDatabase {
            let controller = WyomingServerController()
            controller.applyConfiguration(VoiceToolsServerConfiguration(isEnabled: true, port: 10801))

            controller.applicationDidEnterBackground()

            if Current.isCatalyst {
                // Catalyst has no such suspension, so there the app being open is enough.
                #expect(controller.state != .stopped)
            } else {
                #expect(controller.state == .stopped)
            }
        }
    }

    @Test func readsTheStoredSettingsWhenNoneAreHandedIn() throws {
        try withTestDatabase {
            VoiceToolsServerConfiguration(isEnabled: false, port: 10802).save()
            let controller = WyomingServerController()

            controller.applyConfiguration()

            #expect(controller.state == .stopped)
        }
    }

    /// Coming back to the screen re-binds what leaving it took down.
    @Test func startsAgainOnReturningToTheForeground() throws {
        try withTestDatabase {
            let controller = WyomingServerController()
            controller.applyConfiguration(VoiceToolsServerConfiguration(isEnabled: true, port: 10803))
            controller.applicationDidEnterBackground()

            controller.applicationWillEnterForeground()

            #expect(controller.state != .stopped)
            controller.applyConfiguration(VoiceToolsServerConfiguration(isEnabled: false))
        }
    }
}
