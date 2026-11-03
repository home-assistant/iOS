@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

@Suite(.sharedState)
struct PrivacyViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: PrivacyView())
    }

    /// With a crash reporter and analytics on board, their switches show too; every switch writes
    /// its privacy setting (messaging also sets Firebase Messaging's auto-init, so the test flips
    /// everything back through the screen).
    @MainActor
    @Test func switchesWriteThePrivacySettings() async {
        let previousReporter = Current.crashReporter
        let previousPrivacy = Current.settingsStore.privacy
        defer {
            Current.crashReporter = previousReporter
            Current.settingsStore.privacy = previousPrivacy
        }
        Current.crashReporter = ReportingCrashReporter()

        let driver = await SwiftUIScreenDriver.show(PrivacyView())
        defer { driver.close() }
        // Header, then messaging, alerts, crash reporting and analytics.
        #expect(driver.sectionCount == 5)

        let before = Current.settingsStore.privacy
        await driver.toggleSwitches()
        let after = Current.settingsStore.privacy
        #expect(after.messaging != before.messaging)
        #expect(after.alerts != before.alerts)
        #expect(after.crashes != before.crashes)
        #expect(after.analytics != before.analytics)

        // Flipping them back also puts Firebase Messaging's auto-init back where it was.
        await driver.toggleSwitches()
        #expect(Current.settingsStore.privacy.messaging == before.messaging)
    }
}

/// A crash reporter that says it has both crash reporting and analytics.
private final class ReportingCrashReporter: CrashReporter {
    let hasCrashReporter = true
    let hasAnalytics = true

    func setUserProperty(value: String?, name: String) {}
    func logEvent(event: String, params: [String: Any]) {}
    func logError(_ error: NSError) {}
}
