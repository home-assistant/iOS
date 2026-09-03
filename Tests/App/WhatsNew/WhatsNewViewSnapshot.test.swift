@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

/// Pins the What's New screen: once on the sample release, which is always there, and once per release
/// currently shipping in `WhatsNewCatalog`, so the screen a user sees after updating is reviewed as an
/// image and not only as copy. An empty catalog leaves only the sample. Re-record the references whenever
/// the catalog changes.
struct WhatsNewViewSnapshotTests {
    @MainActor @Test func sampleRelease() {
        MaterialDesignIcons.register()
        assertLightDarkSnapshots(of: WhatsNewView(release: WhatsNewCatalog.mock, onViewed: {}))
    }

    @MainActor @Test func catalogReleases() {
        MaterialDesignIcons.register()
        for release in WhatsNewCatalog.releases {
            assertLightDarkSnapshots(
                of: WhatsNewView(release: release, onViewed: {}),
                named: release.id.rawValue
            )
        }
    }
}
