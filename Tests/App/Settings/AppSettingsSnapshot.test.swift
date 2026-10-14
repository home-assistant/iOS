@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class AppSettingsSnapshotTests: XCTestCase {
    func testNotifyOnLocalPushStateChangesIsCapturedAndApplied() {
        let original = Current.settingsStore.notifyOnLocalPushStateChanges
        defer { Current.settingsStore.notifyOnLocalPushStateChanges = original }

        Current.settingsStore.notifyOnLocalPushStateChanges = true
        let snapshot = AppSettingsSnapshot.capture()
        XCTAssertEqual(snapshot.notifyOnLocalPushStateChanges, true)

        Current.settingsStore.notifyOnLocalPushStateChanges = false
        snapshot.apply()
        XCTAssertTrue(Current.settingsStore.notifyOnLocalPushStateChanges)
    }
}
