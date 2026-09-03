@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

/// Pins every release currently shipping in `WhatsNewCatalog`, so the screen a user sees after updating is
/// reviewed as an image and not only as copy. Re-record the references whenever the catalog changes.
struct WhatsNewViewSnapshotTests {
    @MainActor @Test func catalogReleases() throws {
        try #require(!WhatsNewCatalog.releases.isEmpty, "The catalog has no release to snapshot")
        for release in WhatsNewCatalog.releases {
            assertLightDarkSnapshots(
                of: WhatsNewView(release: release, onViewed: {}),
                named: release.id.rawValue
            )
        }
    }
}
