@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UserNotifications
import WidgetKit

/// The to-do list widget: which list its timeline shows, the items it keeps, how each item's due
/// date reads, and the view drawing every state.
///
/// `.isolatedEnvironment`: servers, the API cache and the database are installed per test and the
/// stub connection answers on the test's own task; the one PromiseKit hop only resumes the await.
@Suite(.isolatedEnvironment)
struct WidgetTodoListTimelineTests {
    @available(iOS 17, *)
    private var provider: WidgetTodoListAppIntentTimelineProvider { .init() }

    // MARK: - Timeline

    @available(iOS 17, *)
    @Test func aFailedRefreshIsNotAnEmptyCompletedList() async throws {
        let (server, _) = try install(entities: []) { _ in .failure(widgetStubUnexpected) }
        let configuration = WidgetTodoListAppIntent()
        configuration.list = .init(
            id: "list",
            entityId: "todo.shopping",
            serverId: server.identifier.rawValue,
            displayString: "Shopping",
            iconName: "checklist"
        )
        let failed = await provider.timeline(for: configuration, family: .systemMedium)
        #expect(failed.entries.first?.loadFailed == true)

        Current.api(for: server)?.connection = WidgetStubConnection { _ in
            .success(HAData(value: [
                "changed_states": [String](),
                "service_response": ["todo.shopping": ["items": [[String: String]]()]],
            ]))
        }
        let empty = await provider.timeline(for: configuration, family: .systemMedium)
        #expect(empty.entries.first?.loadFailed == false)
        #expect(empty.entries.first?.items.isEmpty == true)

        Current.servers = FakeServerManager()
        let missing = await provider.timeline(for: configuration, family: .systemMedium)
        #expect(missing.entries.first?.loadFailed == true)
    }

    // MARK: - Completing an item

    @available(iOS 17, *)
    @Test func completingAnItemSendsTheService() async throws {
        let (server, connection) = try install(entities: []) { _ in .success(.empty) }
        let notifications = RecordingDispatcher()
        Current.notificationDispatcher = notifications
        let intent = TodoItemCompleteAppIntent(
            serverId: server.identifier.rawValue,
            listId: "todo.shopping",
            itemId: "uid-1"
        )
        intent.hapticConfirmation = false
        _ = try await intent.perform()
        #expect(connection.sentCommands == ["services/todo/update_item"])
        #expect(connection.sent.first?.data["status"] as? String == "completed")
        #expect(notifications.ids.isEmpty)

        let failing = WidgetStubConnection { _ in .failure(widgetStubUnexpected) }
        Current.api(for: server)?.connection = failing
        _ = try await intent.perform()
        #expect(failing.sent.count == 1)
        #expect(notifications.ids == [.intentPerformActionFailed])

        let unknown = TodoItemCompleteAppIntent()
        _ = try await unknown.perform()
        #expect(unknown.serverId.isEmpty)
    }

    @available(iOS 17, *)
    @Test func theListPickerNeedsAServerFirst() async throws {
        _ = try install(entities: [("todo-server", "todo.chores", "Chores")]) { _ in .failure(widgetStubUnexpected) }
        let query = TodoListAppEntityQuery()
        let byId = try await query.entities(for: ["todo-server-todo.chores"])
        let suggested = try await query.suggestedEntities()
        let matching = try await query.entities(matching: "Ch")
        #expect(byId.isEmpty)
        #expect(suggested.sections.flatMap(\.items).isEmpty)
        #expect(matching.sections.flatMap(\.items).isEmpty)

        let entity = TodoListAppEntity(
            id: "1",
            entityId: "todo.chores",
            serverId: "todo-server",
            displayString: "Chores",
            iconName: "checklist"
        )
        #expect(!String(describing: entity.displayRepresentation.title).isEmpty)
    }

    // MARK: - Due dates

    @available(iOS 17, *)
    @Test func dueDatesReadRelativeToNow() throws {
        let view = Self.view(items: [])
        let now = Date()
        #expect(view.dueDisplay(for: Self.item(due: nil, raw: nil)) == nil)

        let soon = try #require(view.dueDisplay(for: Self.item(due: now.addingTimeInterval(20), raw: "T")))
        #expect(soon.text == L10n.Widgets.TodoList.DueDate.now)

        let inMinutes = try #require(view.dueDisplay(for: Self.item(due: now.addingTimeInterval(10 * 60), raw: "T")))
        #expect(!inMinutes.isPastDateOnly)
        #expect(!inMinutes.text.isEmpty)

        let minutesAgo = try #require(view.dueDisplay(for: Self.item(due: now.addingTimeInterval(-10 * 60), raw: "T")))
        #expect(!minutesAgo.isPastDateOnly)
        #expect(minutesAgo.text != inMinutes.text)

        let inHours = try #require(view.dueDisplay(for: Self.item(due: now.addingTimeInterval(5 * 3600), raw: "T")))
        #expect(!inHours.isPastDateOnly)

        let today = try #require(view.dueDisplay(for: Self.item(due: now, raw: "2026-01-01")))
        #expect(today.text == L10n.Widgets.TodoList.DueDate.today)

        let yesterday = try #require(view.dueDisplay(for: Self.item(
            due: now.addingTimeInterval(-3 * 24 * 3600),
            raw: "2026-01-01"
        )))
        #expect(yesterday.isPastDateOnly)

        let nextWeek = try #require(view.dueDisplay(for: Self.item(
            due: now.addingTimeInterval(6 * 24 * 3600),
            raw: "2026-01-01"
        )))
        #expect(!nextWeek.isPastDateOnly)
    }

    // MARK: - Rendering

    @available(iOS 17, *)
    @Test @MainActor func theViewDrawsEveryState() {
        let now = Date()
        render(Self.view(items: [
            Self.item(due: nil, raw: nil),
            Self.item(due: now.addingTimeInterval(3600 * 30), raw: "2026-01-01"),
            Self.item(due: now.addingTimeInterval(-3600 * 30), raw: "2026-01-01"),
            Self.item(due: now.addingTimeInterval(600), raw: "T"),
        ]))
        render(Self.view(items: []))
        render(WidgetTodoListView(serverId: "", listId: "", title: "", items: [], isEmpty: true))
    }

    // MARK: - Helpers

    private final class RecordingDispatcher: LocalNotificationDispatcherProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var sent: [NotificationIdentifier] = []

        var ids: [NotificationIdentifier] {
            lock.lock()
            defer { lock.unlock() }
            return sent
        }

        func send(_ notification: LocalNotificationDispatcher.Notification) {
            lock.lock()
            sent.append(notification.id)
            lock.unlock()
        }

        func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {}
    }

    /// Registers one server whose API answers through `respond`, with `entities` (server id,
    /// entity id, name) stored as to-do lists in a fresh in-memory database.
    private func install(
        entities: [(String, String, String)],
        _ respond: @escaping WidgetStubConnection.Responder
    ) throws -> (Server, WidgetStubConnection) {
        let database = try SettingsTestDatabase.make()
        try database.write { db in
            for (serverId, entityId, name) in entities {
                try HAAppEntity(
                    id: "\(serverId)-\(entityId)",
                    entityId: entityId,
                    serverId: serverId,
                    domain: "todo",
                    name: name,
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
            }
        }
        Current.database = { database }
        let servers = FakeServerManager()
        _ = servers.add(identifier: .init(rawValue: "other"), serverInfo: .fake())
        let server = servers.add(identifier: .init(rawValue: "todo-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        for each in servers.all {
            let api = HomeAssistantAPI(server: each)
            api.connection = each == server ? connection : WidgetStubConnection { _ in .failure(widgetStubUnexpected) }
            Current.setCachedApi(api, for: each.identifier)
        }
        return (server, connection)
    }

    @available(iOS 17, *)
    private static func view(items: [TodoListItem]) -> WidgetTodoListView {
        WidgetTodoListView(serverId: "server", listId: "todo.list", title: "Groceries", items: items, isEmpty: false)
    }

    private static func item(due: Date?, raw: String?) -> TodoListItem {
        TodoListItem(
            summary: "Item",
            uid: UUID().uuidString,
            status: "needs_action",
            description: nil,
            dueRaw: raw,
            due: due
        )
    }

    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 380))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }
}
