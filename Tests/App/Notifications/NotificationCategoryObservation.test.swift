import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UserNotifications

/// The app registers its notification categories from the stored ones plus the built-in dynamic
/// actions category, whenever the stored categories change.
/// Shared state: swaps `Current.database` and `Current.modelManager`, and sets the host app's
/// notification categories (restored afterwards).
@Suite(.sharedState)
@MainActor
struct NotificationCategoryObservationTests {
    @Test func storedAndBuiltInCategoriesAreRegistered() async throws {
        let center = UNUserNotificationCenter.current()
        let previousCategories = await center.notificationCategories()
        let previousManager = Current.modelManager
        defer {
            Current.modelManager = previousManager
            center.setNotificationCategories(previousCategories)
        }

        try await SettingsTestDatabase.with { _ in
            // A manager of the test's own, so the observation it starts ends with it.
            Current.modelManager = LegacyModelManager()
            NotificationCategory.setupObserver()

            var registered: Set<UNNotificationCategory> = []
            for _ in 0 ..< 500 where !registered.contains(where: { $0.identifier == "DYNAMIC" }) {
                try await Task.sleep(nanoseconds: 20_000_000)
                registered = await center.notificationCategories()
            }
            #expect(registered.contains { $0.identifier == "DYNAMIC" })
        }
    }
}
