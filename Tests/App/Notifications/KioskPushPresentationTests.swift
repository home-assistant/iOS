import Combine
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing
import UserNotifications

// Serialized: the toast assertions read `ToastPresenter.shared`, which is a singleton these tests
// would otherwise race each other over.
@Suite(.serialized)
struct KioskPushPresentationTests {
    @MainActor
    @Test func ignoresMessagesThatAreNotKioskCommands() throws {
        try withKiosk(settings: KioskSettings()) { manager in
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "Motion detected")
            )

            #expect(options == nil)
        }
    }

    @MainActor
    @Test func ignoresKioskCommandsWhileRemoteCommandsAreRefused() throws {
        let commands = ScreensaverCommandRecorder()
        try withKiosk(settings: KioskSettings(acceptRemoteCommands: false)) { manager in
            commands.record()
            let options = manager.kioskPushPresentationOptions(
                identifier: "notification-1",
                content: content(body: "kiosk_show_screensaver")
            )

            #expect(options == nil)
            #expect(commands.received.isEmpty)
        }
    }

    @MainActor
    @Test func fallsBackToTheDefaultPresentationForAnUnknownKioskCommand() throws {
        try withKiosk(settings: KioskSettings()) { manager in
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
        ToastPresenter.shared.hideCurrent()
        let commands = ScreensaverCommandRecorder()
        try withKiosk(settings: KioskSettings()) { manager in
            commands.record()
            let options = manager.kioskPushPresentationOptions(
                identifier: "confirmed-command",
                content: content(body: "kiosk_show_screensaver")
            )

            #expect(commands.received == [.show])
            // No banner: a kiosk command is an instruction, not something to read.
            let presentation = try #require(options)
            #expect(presentation.isEmpty)
        }

        await drainMainActorWork()
        #expect(ToastPresenter.shared.toast?.id == "confirmed-command")
        #expect(ToastPresenter.shared.toast?.title == L10n.Kiosk.PushCommand.showScreensaver)
        ToastPresenter.shared.hideCurrent()
    }

    @available(iOS 18, *)
    @MainActor
    @Test func runsTheCommandWithoutAToastWhenConfirmationsAreDisabled() async throws {
        ToastPresenter.shared.hideCurrent()
        let commands = ScreensaverCommandRecorder()
        try withKiosk(settings: KioskSettings(showRemoteCommandConfirmations: false)) { manager in
            commands.record()
            let options = manager.kioskPushPresentationOptions(
                identifier: "silent-command",
                content: content(body: "kiosk_show_screensaver")
            )

            // The command still ran and the banner is still suppressed; only the toast is skipped.
            #expect(commands.received == [.show])
            let presentation = try #require(options)
            #expect(presentation.isEmpty)
        }

        await drainMainActorWork()
        #expect(ToastPresenter.shared.toast?.id != "silent-command")
    }

    /// Collects the screensaver commands the kiosk is asked to run, which is how these tests see
    /// whether a push command executed, confirmed on screen or not.
    private final class ScreensaverCommandRecorder {
        private(set) var received: [KioskScreensaverCommand] = []
        private var cancellable: AnyCancellable?

        func record() {
            cancellable = Current.kiosk.screensaverCommandPublisher.sink { [weak self] command in
                self?.received.append(command)
            }
        }
    }

    private func content(body: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = body
        return content
    }

    /// Lets the main-actor task the presentation path enqueues for the toast run before asserting.
    private func drainMainActorWork() async {
        for _ in 0 ..< 10 {
            await MainActor.run {}
        }
    }

    /// Points `Current.kiosk` at `settings` through a fresh in-memory database. Stays synchronous so
    /// the swapped globals are never held across a suspension, where a parallel test could read them.
    @MainActor
    private func withKiosk(settings: KioskSettings, _ body: (NotificationManager) throws -> Void) throws {
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousSensors = Current.sensors
        defer {
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.sensors = previousSensors
        }

        Current.sensors = SensorContainer()
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)
        try database.write { db in
            try settings.insert(db, onConflict: .replace)
        }
        Current.database = { database }
        Current.kiosk = KioskModeManager()

        try body(NotificationManager())
    }
}
