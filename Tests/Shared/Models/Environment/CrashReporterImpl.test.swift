import Foundation
@testable import Shared
import XCTest

final class CrashReporterImplTests: XCTestCase {
    private static let keys = ["crashesEnabled", "analyticsEnabled"]
    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        savedValues = [:]
        for key in Self.keys {
            if let value = Current.settingsStore.prefs.object(forKey: key) {
                savedValues[key] = value
            }
        }
    }

    override func tearDown() {
        for key in Self.keys {
            if let value = savedValues[key] {
                Current.settingsStore.prefs.set(value, forKey: key)
            } else {
                Current.settingsStore.prefs.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testThereIsNoCrashReporterWhetherOrNotCrashesAreShared() {
        for crashes in [false, true] {
            Current.settingsStore.prefs.set(crashes, forKey: "crashesEnabled")
            let reporter = CrashReporterImpl()

            reporter.setup()

            XCTAssertFalse(reporter.hasCrashReporter)
            XCTAssertFalse(reporter.hasAnalytics)
        }
    }

    func testLoggingIsANoOpWhetherOrNotAnalyticsAreShared() {
        let reporter = CrashReporterImpl()
        for analytics in [false, true] {
            Current.settingsStore.prefs.set(analytics, forKey: "analyticsEnabled")

            reporter.setUserProperty(value: "value", name: "property")
            reporter.logEvent(event: "event", params: ["key": "value"])
            reporter.logError(NSError(domain: "test", code: 1))

            XCTAssertFalse(reporter.hasAnalytics)
        }
    }
}
