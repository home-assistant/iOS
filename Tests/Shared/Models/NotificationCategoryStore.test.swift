import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Notification categories persisted through `Current.database()`, and the example automation
/// trigger shown for an action. Each test installs its own in-memory database.
@Suite(.isolatedEnvironment)
struct NotificationCategoryStoreTests {
    private func installDatabase(withTables: Bool = true) throws {
        let database = try DatabaseQueue()
        if withTables {
            try database.createSchemaWithPrivateDefaults()
        }
        Current.database = { database }
    }

    @Test func categoriesSaveFetchAndDelete() throws {
        try installDatabase()
        NotificationCategory(identifier: "ALARM", serverIdentifier: "s", name: "Alarm").save()
        NotificationCategory(identifier: "DOOR", serverIdentifier: "s", name: "Door").save()
        #expect(NotificationCategory.all().count == 2)
        #expect(NotificationCategory.fetch(identifier: "ALARM")?.name == "Alarm")
        #expect(NotificationCategory.fetch(identifier: "MISSING") == nil)

        NotificationCategory.delete(identifiers: [])
        #expect(NotificationCategory.all().count == 2)
        NotificationCategory.delete(identifiers: ["ALARM"])
        #expect(NotificationCategory.all().map(\.identifier) == ["DOOR"])
    }

    @Test func missingSchemaReadsAsEmpty() throws {
        try installDatabase(withTables: false)
        #expect(NotificationCategory.all().isEmpty)
        #expect(NotificationCategory.fetch(identifier: "ALARM") == nil)
        NotificationCategory(identifier: "ALARM").save()
        NotificationCategory.delete(identifiers: ["ALARM"])
        #expect(NotificationCategory.all().isEmpty)
    }

    @Test func exampleTriggersDescribeTheEvent() {
        let api = HomeAssistantAPI(server: .fake())
        let withText = NotificationAction.exampleTrigger(
            api: api,
            identifier: "REPLY",
            category: "MSG",
            textInput: true
        )
        #expect(withText.contains("event_type: ios.notification_action_fired"))
        #expect(withText.contains("actionName: REPLY"))
        #expect(withText.contains("textInput"))
        let plain = NotificationAction.exampleTrigger(api: api, identifier: "OK", category: nil, textInput: false)
        #expect(!plain.contains("textInput"))
    }
}
