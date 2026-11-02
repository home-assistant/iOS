import Foundation
@testable import Shared

/// Points `Current.settingsStore` at a defaults suite that only this test reads and writes, until
/// `restore()` puts the previous store back and deletes the suite.
///
/// The app group defaults are one file per simulator, shared by every process on it. `Tests-Unit`
/// runs the Tests-Shared XCTest classes in several processes on the same simulator at once, so a sensor enablement
/// reset or a Focus reading written by a class in another process lands in the middle of this
/// one. A suite of its own gives the test its premise back: it starts empty, and nothing else
/// writes to it.
///
/// Install it before building anything that holds on to `prefs` (`FocusStatusWrapper`,
/// `FocusFilterWrapper`), and restore it after the test's own cleanup. For XCTest classes: the
/// suite is one per process, which XCTest runs a class at a time in, so it is emptied on the way
/// in and out rather than named per test (each name would leave an empty plist on the simulator).
public final class PrivateSettingsStore {
    private let suiteName = "io.home-assistant.tests.\(ProcessInfo.processInfo.processIdentifier)"
    private let previous: SettingsStore
    public let prefs: UserDefaults

    public init() {
        guard let prefs = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create the defaults suite \(suiteName)")
        }
        // Empty even if a crashed process with the same identifier left something behind.
        prefs.removePersistentDomain(forName: suiteName)
        self.prefs = prefs
        self.previous = Current.settingsStore
        Current.settingsStore = SettingsStore(prefs: prefs)
    }

    public func restore() {
        Current.settingsStore = previous
        prefs.removePersistentDomain(forName: suiteName)
    }
}
