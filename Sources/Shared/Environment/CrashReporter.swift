import Foundation

public protocol CrashReporter {
    var hasCrashReporter: Bool { get }
    var hasAnalytics: Bool { get }

    func setUserProperty(value: String?, name: String)
    func logEvent(event: String, params: [String: Any])
    func logError(_ error: NSError)
}

public class CrashReporterImpl: CrashReporter {
    public var hasCrashReporter: Bool = false
    public var hasAnalytics: Bool = false

    internal func setup() {
        guard Current.settingsStore.privacy.crashes else {
            return
        }

        guard Constants.BundleID.starts(with: "io.robbie.") else {
            return
        }

        // no current crash reporter
        hasCrashReporter = false
        hasAnalytics = false
    }

    public func setUserProperty(value: String?, name: String) {
        // no current analytics/crash reporter
    }

    public func logEvent(event: String, params: [String: Any]) {
        guard Current.settingsStore.privacy.analytics else { return }

        Current.Log.verbose("event \(event): \(params)")
        // no current analytics logger
    }

    public func logError(_ error: NSError) {
        // crash reporting is controlled by the crashes key, but this is more like analytics
        guard Current.settingsStore.privacy.analytics else { return }

        Current.Log.error("error: \(error.debugDescription)")
        // no current error logger
    }
}
