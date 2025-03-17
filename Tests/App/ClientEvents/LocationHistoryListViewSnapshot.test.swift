@testable import HomeAssistant
import RealmSwift
import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct LocationHistoryListViewSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func snapshots() {
        LocationHistoryListView_Previews
            .configuration
			.assertLightDarkSnapshots(drawHierarchyInKeyWindow: true)
    }
}
