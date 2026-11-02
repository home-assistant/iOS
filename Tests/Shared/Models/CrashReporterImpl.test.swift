import Foundation
@testable import Shared
import SharedTesting
import Testing

/// The placeholder crash reporter honours the privacy settings, which live in the shared defaults.
@Suite(.sharedState)
struct CrashReporterImplTests {
    @Test func reportingFollowsThePrivacySettings() {
        let store = Current.settingsStore
        let previous = store.privacy
        defer { store.privacy = previous }

        for enabled in [true, false] {
            var privacy = previous
            privacy.crashes = enabled
            privacy.analytics = enabled
            store.privacy = privacy

            let reporter = CrashReporterImpl()
            reporter.setup()
            reporter.setUserProperty(value: "value", name: "name")
            reporter.logEvent(event: "event", params: ["key": 1])
            reporter.logError(NSError(domain: "test", code: 1))
            #expect(!reporter.hasCrashReporter)
            #expect(!reporter.hasAnalytics)
        }
    }
}
