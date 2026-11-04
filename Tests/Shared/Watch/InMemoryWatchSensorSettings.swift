import Foundation
@testable import Shared

/// Watch sensor settings held in memory, standing in for `WatchUserDefaults` in tests.
final class InMemoryWatchSensorSettings: WatchSensorSettings {
    private let lock = NSLock()
    private var enabledByServer = [Identifier<Server>: Set<String>]()
    private var reportedAt: Date?
    private var error: String?

    init(lastSensorReportAt: Date? = nil) {
        self.reportedAt = lastSensorReportAt
    }

    func enabledSensorIDs(forServer serverID: Identifier<Server>) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return enabledByServer[serverID] ?? []
    }

    func setEnabledSensorIDs(_ uniqueIDs: Set<String>, forServer serverID: Identifier<Server>) {
        lock.lock()
        defer { lock.unlock() }
        enabledByServer[serverID] = uniqueIDs
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
