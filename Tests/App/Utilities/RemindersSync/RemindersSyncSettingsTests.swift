import Foundation
@testable import HomeAssistant
import Testing

struct RemindersSyncSettingsTests {
    @Test func testDefaultsExcludeCompletedItems() {
        #expect(RemindersSyncSettings().includeCompletedItems == false)
    }

    @Test func testDecodingSettingsSavedBeforeTheCompletedItemsSettingKeepsTheOtherValues() throws {
        let legacy = Data(
            """
            {"foregroundRefreshInterval":300,"backgroundRefreshInterval":3600,"conflictResolution":"reminders"}
            """.utf8
        )
        let settings = try JSONDecoder().decode(RemindersSyncSettings.self, from: legacy)
        #expect(settings.foregroundRefreshInterval == 300)
        #expect(settings.backgroundRefreshInterval == 3600)
        #expect(settings.conflictResolution == .reminders)
        #expect(settings.includeCompletedItems == false)
    }

    @Test func testRoundTripsIncludeCompletedItems() throws {
        let settings = RemindersSyncSettings(includeCompletedItems: true)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(RemindersSyncSettings.self, from: data)
        #expect(decoded == settings)
    }
}
