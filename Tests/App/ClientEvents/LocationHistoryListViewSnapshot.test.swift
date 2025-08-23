@testable import HomeAssistant
import SharedTesting
import Testing

struct LocationHistoryListViewSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func snapshots() {
        LocationHistoryListView_Previews
            .configuration
            .assertLightDarkSnapshots(drawHierarchyInKeyWindow: true)
    }
}
