import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Serves a fixed history instead of the app group file.
private final class FakeNotificationHistoryStore: NotificationHistoryStoreProtocol {
    var entries: [NotificationHistoryEntry]

    init(entries: [NotificationHistoryEntry]) {
        self.entries = entries
    }

    func record(_ entry: NotificationHistoryEntry) {
        entries.append(entry)
    }

    func getEntries() -> [NotificationHistoryEntry] {
        entries
    }

    func clearAllEntries() {
        entries = []
    }
}

/// Lays the notification settings screens out so SwiftUI evaluates their bodies, against an
/// in-memory database and a fake history so nothing on the device is read or changed.
@MainActor
final class NotificationScreensRenderTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var previousHistoryStore: NotificationHistoryStoreProtocol!
    private var previousPushID: String?

    override func setUp() async throws {
        let database = try DatabaseQueue()
        try NotificationCategoryTable().createIfNeeded(database: database)
        try NotificationSnoozeActionTable().createIfNeeded(database: database)
        self.database = database
        previousDatabase = Current.database
        Current.database = { database }

        previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 0)

        previousHistoryStore = Current.notificationHistoryStore
        previousPushID = Current.settingsStore.pushID
        // Without a push ID the debug screen doesn't ask the push server for its rate limits.
        Current.settingsStore.pushID = nil
    }

    override func tearDown() async throws {
        Current.database = previousDatabase
        Current.servers = previousServers
        Current.notificationHistoryStore = previousHistoryStore
        Current.settingsStore.pushID = previousPushID
        database = nil
    }

    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View, height: CGFloat = 1600) async {
        let controller = UIHostingController(rootView: view.injectingViewControllerProvider())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        // `onAppear` loads most of these screens' content, which lands after the first pass.
        try? await Task.sleep(nanoseconds: 50_000_000)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)

        window.isHidden = true
        window.rootViewController = nil
    }

    private func makeCategory(isServerControlled: Bool) -> NotificationCategory {
        NotificationCategory(
            identifier: isServerControlled ? "server_alarm" : "local_alarm",
            name: isServerControlled ? "Server alarm" : "Local alarm",
            isServerControlled: isServerControlled,
            hiddenPreviewsBodyPlaceholder: "Hidden",
            categorySummaryFormat: "%u alarms",
            actions: [
                NotificationAction(
                    identifier: "SILENCE",
                    title: "Silence",
                    isServerControlled: isServerControlled,
                    destructive: true
                ),
                NotificationAction(
                    identifier: "REPLY",
                    title: "",
                    textInput: true,
                    isServerControlled: isServerControlled
                ),
            ]
        )
    }

    func testRendersTheSoundsScreen() async {
        await render(NavigationView { NotificationSoundsView() })
    }

    func testRendersTheHistoryWithEntriesOfEveryKind() async {
        Current.notificationHistoryStore = FakeNotificationHistoryStore(entries: [
            NotificationHistoryEntry(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                kind: .remote,
                title: "Door opened",
                subtitle: "Front door",
                body: "Someone opened the front door",
                payloadJSON: #"{"aps":{"alert":"Door opened"},"tags":[1,true,null]}"#
            ),
            NotificationHistoryEntry(
                date: Date(timeIntervalSince1970: 1_700_000_100),
                kind: .local,
                body: "Body only"
            ),
            NotificationHistoryEntry(
                date: Date(timeIntervalSince1970: 1_700_000_200),
                kind: .liveActivityLocal,
                title: "Washer"
            ),
        ])
        let viewModel = NotificationHistoryViewModel()
        viewModel.loadEntries()
        XCTAssertEqual(viewModel.entries.map(\.kind), [.liveActivityLocal, .local, .remote])

        await render(NavigationView { NotificationHistoryView() })
    }

    func testRendersAnEmptyHistory() async {
        Current.notificationHistoryStore = FakeNotificationHistoryStore(entries: [])
        await render(NavigationView { NotificationHistoryView() })
    }

    func testRendersTheCategoryListWithLocalAndServerCategories() async {
        makeCategory(isServerControlled: false).save()
        makeCategory(isServerControlled: true).save()

        await render(NavigationView { NotificationCategoryListView() })
    }

    func testRendersAnEmptyCategoryList() async {
        await render(NavigationView { NotificationCategoryListView() })
    }

    func testRendersTheCategoryEditorForANewCategory() async {
        await render(NavigationView { NotificationCategoryEditorView(category: nil) { _ in } })
    }

    func testRendersTheCategoryEditorForALocalCategory() async {
        let category = makeCategory(isServerControlled: false)
        await render(NavigationView { NotificationCategoryEditorView(category: category) { _ in } })
    }

    func testRendersTheCategoryEditorForAServerCategory() async {
        let category = makeCategory(isServerControlled: true)
        await render(NavigationView { NotificationCategoryEditorView(category: category) { _ in } })
    }

    func testRendersTheActionEditorForANewAction() async {
        let category = makeCategory(isServerControlled: false)
        await render(NavigationView {
            NotificationActionEditorView(category: category, action: nil) { _ in }
        })
    }

    func testRendersTheActionEditorForATextInputAction() async {
        let category = makeCategory(isServerControlled: false)
        await render(NavigationView {
            NotificationActionEditorView(category: category, action: category.actions[1]) { _ in }
        })
    }

    func testRendersTheActionEditorForAServerAction() async {
        let category = makeCategory(isServerControlled: true)
        await render(NavigationView {
            NotificationActionEditorView(category: category, action: category.actions[0]) { _ in }
        })
    }

    func testRendersTheRateLimitsOnceLoaded() async {
        let response = RateLimitResponse(
            target: "push-target",
            rateLimits: .init(
                attempts: 10,
                successful: 9,
                errors: 1,
                total: 10,
                maximum: 300,
                remaining: 290,
                resetsAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        XCTAssertEqual(response.rateLimits.remaining, 290)

        await render(NavigationView {
            NotificationRateLimitView(initialPromise: Promise.value(response))
        })
    }

    func testRendersTheRateLimitsError() async {
        await render(NavigationView {
            NotificationRateLimitView(
                initialPromise: Promise<RateLimitResponse>(error: URLError(.notConnectedToInternet))
            )
        })
    }

    func testRendersTheSnoozePresets() async {
        await render(NavigationView { NotificationSnoozeActionsView() })
    }

    func testRendersTheDebugScreens() async {
        await render(NavigationView { NotificationDebugView() })
        await render(NavigationView { NotificationDebugNotificationsView() })
    }

    func testDebugViewModelShowsNotRegisteredWithoutAPushID() {
        let viewModel = NotificationDebugViewModel()

        XCTAssertNil(viewModel.pushID)
        XCTAssertEqual(
            viewModel.pushIDDisplay,
            L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
        )
    }
}
