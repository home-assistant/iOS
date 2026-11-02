import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit
import UserNotifications

/// Shared state: the action editor it presents reads `Current.apis` from the main run loop, so the
/// servers and API cache are swapped globally.
@Suite(.sharedState)
@MainActor
struct NotificationCategoryEditorViewRenderTests {
    private static let actions = [
        NotificationAction(identifier: "OPEN", title: "Open"),
        NotificationAction(identifier: "IGNORE", title: ""),
    ]

    private func show(
        _ category: NotificationCategory?,
        onDismiss: @escaping (NotificationCategory?) -> Void = { _ in }
    ) async -> SwiftUIScreenDriver {
        await SwiftUIScreenDriver.show(
            NotificationCategoryEditorView(category: category, onDismiss: onDismiss)
                .environmentObject(ViewControllerProvider())
        )
    }

    @Test func newCategoryIsValidatedThenSaved() async throws {
        try await withServer {
            var results: [NotificationCategory?] = []
            let driver = await show(nil) { results.append($0) }
            defer { driver.close() }

            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            await #expect(driver.waitUntil { driver.alert != nil })
            await driver.tapAlertButton()
            #expect(results.isEmpty)

            await driver.type("door_alerts")
            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            await #expect(driver.waitUntil { !results.isEmpty })
            let saved = try #require(results.first ?? nil)
            #expect(saved.name == "door_alerts")
            #expect(saved.identifier == "door_alerts")
        }
    }

    /// The eye in the bottom toolbar sends a preview notification carrying the category's actions.
    @Test func previewSendsANotificationWithTheCategory() async throws {
        try await withServer {
            let driver = await show(NotificationCategory(identifier: "b2_preview", name: "Preview"))
            defer {
                driver.close()
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: ["b2_preview"])
                center.removeDeliveredNotifications(withIdentifiers: ["b2_preview"])
            }
            let items = driver.navigationController?.topViewController?.toolbarItems ?? []
            let actionable = items.filter { $0.action != nil }
            try #require(!actionable.isEmpty)
            // Help comes first, the preview last.
            let preview = try #require(actionable.last)
            let sent = try UIApplication.shared.sendAction(
                #require(preview.action),
                to: preview.target,
                from: preview,
                for: nil
            )
            #expect(sent)
            await driver.settle()
        }
    }

    /// Tapping an action, then "Add", presents the action editor sheet each time.
    @Test func existingCategoryOpensItsActionEditors() async throws {
        try await withServer {
            let category = NotificationCategory(
                identifier: "doorbell",
                name: "Doorbell",
                hiddenPreviewsBodyPlaceholder: "Hidden",
                categorySummaryFormat: "%u more",
                actions: Self.actions
            )
            let driver = await show(category)
            defer { driver.close() }

            // Settings, hidden preview, summary, actions, YAML preview.
            #expect(driver.sectionCount == 5)
            let actionsSection = 3
            #expect(driver.rowCount(inSection: actionsSection) == Self.actions.count + 1)

            await driver.tapRow(IndexPath(item: 0, section: actionsSection))
            await #expect(driver.waitUntil { driver.presented != nil })
            await driver.dismissPresented()

            await driver.tapRow(IndexPath(item: Self.actions.count, section: actionsSection))
            await #expect(driver.waitUntil { driver.presented != nil })
            await driver.dismissPresented()
        }
    }

    /// The help button, first in the bottom toolbar, opens the documentation in the browser.
    @Test func helpOpensTheDocumentation() async throws {
        try await withServer {
            try await RecordingURLOpener.with { opener in
                let driver = await show(NotificationCategory(identifier: "help", name: "Help"))
                defer { driver.close() }
                let items = driver.navigationController?.topViewController?.toolbarItems ?? []
                let help = try #require(items.first { $0.action != nil })
                let sent = try UIApplication.shared.sendAction(
                    #require(help.action),
                    to: help.target,
                    from: help,
                    for: nil
                )
                #expect(sent)
                await driver.settle()
                #expect(opener.openedURLs.count == 1)
            }
        }
    }

    @Test func cancellingHandsBackNothing() async throws {
        try await withServer {
            var results: [NotificationCategory?] = []
            let driver = await show(NotificationCategory(identifier: "x", name: "X")) { results.append($0) }
            defer { driver.close() }
            await #expect(driver.tapBarButton(titled: L10n.cancelLabel))
            await #expect(driver.waitUntil { results.count == 1 })
            #expect(results.first == .some(nil))
        }
    }

    @Test func serverControlledCategoryIsReadOnly() async throws {
        try await withServer {
            let category = NotificationCategory(
                identifier: "server",
                name: "Server",
                isServerControlled: true,
                actions: Self.actions
            )
            let driver = await show(category)
            defer { driver.close() }
            // Settings, actions and YAML preview only.
            #expect(driver.sectionCount == 3)
            await #expect(!driver.tapBarButton(titled: L10n.saveLabel))
        }
    }

    /// A category at the action cap no longer offers "Add".
    @Test func fullCategoryHidesAdd() async throws {
        try await withServer {
            let actions = (0 ..< 10).map { NotificationAction(identifier: "A\($0)", title: "Action \($0)") }
            let driver = await show(NotificationCategory(identifier: "full", name: "Full", actions: actions))
            defer { driver.close() }
            #expect(driver.rowCount(inSection: 3) == 10)
        }
    }

    private func withServer(_ body: () async throws -> Void) async throws {
        let previous = Current.servers
        let servers = FakeServerManager(initial: 1)
        let api = HomeAssistantAPI(server: servers.all[0])
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: servers.all[0].identifier)
        Current.servers = servers
        defer {
            Current.resetAPICache(for: servers.all.map(\.identifier))
            Current.servers = previous
        }
        try await body()
    }
}
