@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

/// Pins the release currently shipping in `WhatsNewCatalog`, so the screen a user sees after updating is
/// reviewed as an image and not only as copy. Re-record the references whenever the catalog changes.
struct WhatsNewViewSnapshotTests {
    @MainActor @Test func currentRelease() throws {
        let release = try #require(WhatsNewCatalog.release, "The catalog has no release to snapshot")
        assertLightDarkSnapshots(of: WhatsNewView(release: release, onViewed: {}))
    }
}
