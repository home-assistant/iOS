import Foundation
@testable import Shared

/// Watch sensor settings held in memory, standing in for `WatchUserDefaults` in tests.
final class InMemoryWatchSensorSettings: WatchSensorSettings {
    private let lock = NSLock()
    private var enabled = Set<String>()
    private var reportedAt: Date?
    private var error: String?

    init(enabledSensorIDs: Set<String> = [], lastSensorReportAt: Date? = nil) {
        self.enabled = enabledSensorIDs
        self.reportedAt = lastSensorReportAt
    }

    var enabledSensorIDs: Set<String> {
        get { lock.lock(); defer { lock.unlock() }; return enabled }
        set { lock.lock(); defer { lock.unlock() }; enabled = newValue }
    }

    var lastSensorReportAt: Date? {
        get { lock.lock(); defer { lock.unlock() }; return reportedAt }
        set { lock.lock(); defer { lock.unlock() }; reportedAt = newValue }
    }

    var lastSensorReportError: String? {
        get { lock.lock(); defer { lock.unlock() }; return error }
        set { lock.lock(); defer { lock.unlock() }; error = newValue }
    }
}
