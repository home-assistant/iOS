@testable import HomeAssistant
import RealmSwift
import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

private extension CGFloat {
    static let width: CGFloat = 400
    static let height: CGFloat = 867
}

struct LocationHistoryListViewSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func snapshots() {
        LocationHistoryListView_Previews
            .configuration
            .assertLightDarkSnapshots(
                layout: .fixed(width: .width, height: .height),
                traits: .iPhone13(.portrait)
            )
    }
}
