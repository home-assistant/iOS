#if os(iOS)
import Foundation
@testable import Shared
import Testing

/// Serialized because every test writes the shared `UserDefaults.standard` key behind the property.
@Suite(.serialized)
struct WatchMirrorPeerVersionTests {
    private let key = "watchMirrorPeerVersion"

    private func preservingStoredValue(_ work: () -> Void) {
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        work()
    }

    @Test func defaultsToLegacyUntilAWatchAdvertisesAVersion() {
        preservingStoredValue {
            UserDefaults.standard.removeObject(forKey: key)
            #expect(WatchMirrorPushCoordinator.peerMirrorVersion == WatchDatabaseMirror.legacyVersion)
        }
    }

    @Test func remembersTheAdvertisedVersion() {
        preservingStoredValue {
            WatchMirrorPushCoordinator.peerMirrorVersion = WatchDatabaseMirror.fullReferenceVersion
            #expect(WatchMirrorPushCoordinator.peerMirrorVersion == WatchDatabaseMirror.fullReferenceVersion)
            #expect(UserDefaults.standard.integer(forKey: key) == WatchDatabaseMirror.fullReferenceVersion)

            WatchMirrorPushCoordinator.peerMirrorVersion = WatchDatabaseMirror.legacyVersion
            #expect(WatchMirrorPushCoordinator.peerMirrorVersion == WatchDatabaseMirror.legacyVersion)
        }
    }
}
#endif
