@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class AppSettingsSnapshotTests: XCTestCase {
    func testNotifyOnLocalPushStateChangesIsCapturedAndApplied() {
        let original = Current.settingsStore.notifyOnLocalPushStateChanges
        defer { Current.settingsStore.notifyOnLocalPushStateChanges = original }

        Current.settingsStore.notifyOnLocalPushStateChanges = true
        XCTAssertEqual(AppSettingsSnapshot.capture().notifyOnLocalPushStateChanges, true)

        // An otherwise empty snapshot only touches this one setting, so applying it cannot
        // re-fire the privacy, location or app icon observers of the test host.
        Current.settingsStore.notifyOnLocalPushStateChanges = false
        var snapshot = AppSettingsSnapshot()
        snapshot.notifyOnLocalPushStateChanges = true
        snapshot.apply()
        XCTAssertTrue(Current.settingsStore.notifyOnLocalPushStateChanges)
    }
}
