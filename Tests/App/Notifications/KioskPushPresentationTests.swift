import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing
import UserNotifications

struct KioskPushPresentationTests {
    @MainActor
    @Test func ignoresMessagesThatAreNotKioskCommands() async throws {
        try await withKiosk(settings: KioskSettings()) { manager in
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "Motion detected")
            )

            #expect(options == nil)
        }
    }

    @MainActor
    @Test func ignoresKioskCommandsWhileRemoteCommandsAreRefused() async throws {
        let settings = KioskSettings(acceptRemoteCommands: false)
        try await withKiosk(settings: settings) { manager in
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "kiosk_show_screensaver")
            )

            #expect(options == nil)
        }
    }

    @MainActor
    @Test func fallsBackToTheDefaultPresentationForAnUnknownKioskCommand() async throws {
        try await withKiosk(settings: KioskSettings()) { manager in
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "kiosk_teleport")
            )

            #expect(options == nil)
        }
    }

    @available(iOS 18, *)
    @MainActor
    @Test func runsTheCommandAndConfirmsItWithAToast() async throws {
        try await withKiosk(settings: KioskSettings()) { manager in
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "kiosk_show_screensaver")
            )

            // No banner: a kiosk command is an instruction, not something to read.
            let presentation = try #require(options)
            #expect(presentation.isEmpty)
            await drainMainActorWork()
            #expect(ToastPresenter.shared.toast?.id == "notification-1")
            #expect(ToastPresenter.shared.toast?.title == L10n.Kiosk.PushCommand.showScreensaver)
        }
    }

    @available(iOS 18, *)
    @MainActor
    @Test func runsTheCommandWithoutAToastWhenConfirmationsAreDisabled() async throws {
        let settings = KioskSettings(showRemoteCommandConfirmations: false)
        try await withKiosk(settings: settings) { manager in
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "kiosk_show_screensaver")
            )

            // The command still ran and the banner is still suppressed; only the toast is skipped.
            let presentation = try #require(options)
            #expect(presentation.isEmpty)
            await drainMainActorWork()
            #expect(ToastPresenter.shared.toast == nil)
        }
    }

    private func content(body: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = body
        return content
    }

    /// Lets the main-actor task the presentation path enqueues for the toast run before asserting.
    @MainActor
    private func drainMainActorWork() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    /// Points `Current.kiosk` at `settings` through a fresh in-memory database, and leaves no toast
    /// behind for the next test.
    @MainActor
    private func withKiosk(
        settings: KioskSettings,
        _ body: (NotificationManager) async throws -> Void
    ) async throws {
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousSensors = Current.sensors
        defer {
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.sensors = previousSensors
            if #available(iOS 18, *) {
                ToastPresenter.shared.hideCurrent()
            }
        }

        Current.sensors = SensorContainer()
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)
        try database.write { db in
            try settings.insert(db, onConflict: .replace)
        }
        Current.database = { database }
        Current.kiosk = KioskModeManager()
        if #available(iOS 18, *) {
            ToastPresenter.shared.hideCurrent()
        }

        try await body(NotificationManager())
    }
}
