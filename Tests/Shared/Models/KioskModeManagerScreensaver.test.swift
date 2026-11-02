import Combine
import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// The kiosk manager persisting screensaver settings and publishing transient UI state, against an
/// in-memory database installed in each test's own environment.
@MainActor
@Suite(.isolatedEnvironment)
struct KioskModeManagerScreensaverTests {
    private func installDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try database.createSchemaWithPrivateDefaults()
        Current.database = { database }
        return database
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test func screensaverSettingsArePersistedAndObserved() async throws {
        let database = try installDatabase()
        let manager = KioskModeManager()

        manager.setScreensaverMode(.blank)
        manager.setScreensaverDimLevel(1.7)
        let stored = try await database.read { db in try KioskSettings.fetchOne(db) }
        #expect(stored?.screensaver.mode == .blank)
        #expect(stored?.screensaver.dimLevel == 1)

        manager.setScreensaverDimLevel(-1)
        let observed = await waitUntil { manager.settings.screensaver.dimLevel == 0 }
        #expect(observed)
        #expect(manager.settings.screensaver.mode == .blank)
    }

    @Test func transientStateIsPublished() async throws {
        _ = try installDatabase()
        let manager = KioskModeManager()
        var commands: [KioskScreensaverCommand] = []
        var overlay: [Bool] = []
        var visible: [Bool] = []
        let cancellables: [AnyCancellable] = [
            manager.screensaverCommandPublisher.sink { commands.append($0) },
            manager.cameraOverlayVisiblePublisher.sink { overlay.append($0) },
            manager.screensaverVisiblePublisher.sink { visible.append($0) },
        ]
        defer { cancellables.forEach { $0.cancel() } }

        manager.requestScreensaver(.show)
        manager.requestScreensaver(.hide)
        manager.setCameraOverlayVisible(true)
        manager.setScreensaverVisible(true)
        #expect(commands == [.show, .hide])
        #expect(overlay.last == true)
        #expect(visible.last == true)
        #expect(manager.isCameraOverlayVisible)
        #expect(manager.isScreensaverVisible)
    }

    @Test func writesWithoutASchemaAreLogged() throws {
        let database = try DatabaseQueue()
        Current.database = { database }
        let manager = KioskModeManager()
        manager.setScreensaverMode(.clock)
        manager.setScreensaverDimLevel(0.5)
        #expect(manager.settings.screensaver.mode == KioskSettings().screensaver.mode)
    }
}
