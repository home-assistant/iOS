@testable import HomeAssistant
import RealmSwift
import Shared
import SnapshotTesting
import SwiftUI
import Testing

private extension CGFloat {
    static let width: CGFloat = 400
    static let height: CGFloat = 867
}

struct LocationHistoryListViewSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func snapshotEmptyListTest() {
        let executionIdentifier = UUID().uuidString
        Current.realm = {
            try! Realm(
                configuration: .init(inMemoryIdentifier: executionIdentifier)
            )
        }
        let view = NavigationView {
            LocationHistoryListView()
        }
        assertSnapshots(
            of: view,
            as: makeDefaultStrategies()
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func snapshotListTestWithContent() throws {
        let view = NavigationView {
            LocationHistoryListView()
        }
        Current.date = { Date(timeIntervalSince1970: 1_740_766_173) }
        let executionIdentifier = UUID().uuidString
        Current.realm = {
            try! Realm(
                configuration: .init(inMemoryIdentifier: executionIdentifier)
            )
        }
        let realm = Current.realm()
        realm.reentrantWrite {
            realm.add([
                LocationHistoryEntry(
                    updateType: .Manual,
                    location: .init(latitude: 41.1234, longitude: 52.2),
                    zone: .defaultSettingValue,
                    accuracyAuthorization: .fullAccuracy,
                    payload: "payload"
                ),
                LocationHistoryEntry(
                    updateType: .Periodic,
                    location: nil,
                    zone: nil,
                    accuracyAuthorization: .reducedAccuracy,
                    payload: "payload"
                ),
            ])
        }
        assertSnapshots(
            of: view,
            as: makeDefaultStrategies()
        )
    }
}
