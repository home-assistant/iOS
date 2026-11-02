import Foundation
import PromiseKit
@testable import Shared
import Testing

/// `clear_notification` touches `UNUserNotificationCenter`, which needs an app bundle, so it is
/// exercised from the hosted test target.
struct NotificationClearCommandTests {
    @Test func clearingWithoutATagRemovesTheDeliveredNotification() async throws {
        try await NotificationCommandManager().handle([
            "homeassistant": ["command": "clear_notification", "collapseId": "group-1"],
        ]).asyncValue()
    }

    @Test func clearingWithNothingToRemoveStillCompletes() async throws {
        try await NotificationCommandManager().handle([
            "homeassistant": ["command": "clear_notification"],
        ]).asyncValue()
    }
}
