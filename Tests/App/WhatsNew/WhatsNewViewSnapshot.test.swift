@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

/// Pins the What's New screens: the list once on the sample release, which is always there, and once per
/// release currently shipping in `WhatsNewCatalog`, plus every in-app article those releases link to. The
/// screen a user sees after updating is reviewed as an image and not only as copy. An empty catalog leaves
/// only the sample. Re-record the references whenever the catalog changes.
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

    @MainActor @Test func catalogArticles() {
        MaterialDesignIcons.register()
        for release in WhatsNewCatalog.releases {
            for item in release.items {
                guard case let .article(article) = item.destination else { continue }
                // Rendered without the navigation stack that pushes it in the app: the bar's scroll-edge
                // appearance is not settled at capture time and made the reference flap between runs.
                assertLightDarkSnapshots(
                    of: WhatsNewArticleView(article: article),
                    named: "\(release.id.rawValue)-\(item.id)"
                )
            }
        }
    }
}
