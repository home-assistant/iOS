@testable import HomeAssistant
@testable import Shared
import Testing
import Version

@Suite(.serialized)
struct WhatsNewEngineTests {
    private let seenWhatsNewReleaseIDsKey = "seenWhatsNewReleaseIDs"

    @Test func releaseToShowReturnsMatchingCurrentVersionAndPlatform() {
        let matchingRelease = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone, .iPad]
        )
        let otherVersionRelease = Self.release(
            version: .init(major: 2026, minor: 7, patch: 0),
            targetPlatforms: [.iPhone]
        )

        let engine = WhatsNewEngine(
            releases: [otherVersionRelease, matchingRelease],
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPad },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == matchingRelease)
    }

    @Test func releaseToShowReturnsNilWhenReleaseWasAlreadySeen() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone]
        )

        let engine = WhatsNewEngine(
            releases: [release],
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            hasSeenRelease: { $0 == release.releaseID }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func releaseToShowReturnsNilWhenPlatformDoesNotMatch() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.mac]
        )

        let engine = WhatsNewEngine(
            releases: [release],
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func latestReleaseReturnsNewestReleaseForCurrentPlatformIgnoringSeenState() {
        let olderRelease = Self.release(
            version: .init(major: 2026, minor: 5, patch: 0),
            targetPlatforms: [.iPhone]
        )
        let newestRelease = Self.release(
            version: .init(major: 2026, minor: 7, patch: 0),
            targetPlatforms: [.iPhone, .iPad]
        )
        let otherPlatformRelease = Self.release(
            version: .init(major: 2026, minor: 8, patch: 0),
            targetPlatforms: [.mac]
        )

        let engine = WhatsNewEngine(
            releases: [olderRelease, newestRelease, otherPlatformRelease],
            currentVersion: { Version(major: 2026, minor: 7, patch: 0) },
            currentPlatform: { .iPad },
            hasSeenRelease: { _ in true }
        )

        #expect(engine.latestRelease() == newestRelease)
    }

    @Test func appVersionUsesMajorMinorPatchComparisonAndDefaultsMissingComponentsToZero() {
        let majorOnlyVersion = WhatsNewAppVersion(Version(major: 2026))
        let patchVersion = WhatsNewAppVersion(Version(major: 2026, minor: 6, patch: 1))

        #expect(majorOnlyVersion == WhatsNewAppVersion(major: 2026, minor: 0, patch: 0))
        #expect(WhatsNewAppVersion(major: 2026, minor: 6, patch: 0) < patchVersion)
        #expect(patchVersion.description == "2026.6.1")
    }

    @Test func releaseIDIsStableWhenTargetPlatformsAreRepeatedOrUnordered() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPad, .iPhone, .iPad]
        )

        #expect(release.releaseID == "2026.6.0-iPad,iPhone")
    }

    @Test func settingsStorePersistsSeenReleaseIDsWithoutDroppingExistingValues() {
        Current.settingsStore.prefs.removeObject(forKey: seenWhatsNewReleaseIDsKey)
        defer { Current.settingsStore.prefs.removeObject(forKey: seenWhatsNewReleaseIDsKey) }

        Current.settingsStore.markWhatsNewSeen(releaseID: "2026.6.0-iPhone")
        Current.settingsStore.markWhatsNewSeen(releaseID: "2026.7.0-iPad")

        #expect(Current.settingsStore.hasSeenWhatsNew(releaseID: "2026.6.0-iPhone"))
        #expect(Current.settingsStore.hasSeenWhatsNew(releaseID: "2026.7.0-iPad"))
        #expect(!Current.settingsStore.hasSeenWhatsNew(releaseID: "2026.8.0-mac"))
    }

    private static func release(
        version: WhatsNewAppVersion,
        targetPlatforms: [WhatsNewTargetPlatform]
    ) -> WhatsNewRelease {
        WhatsNewRelease(
            version: version,
            targetPlatforms: targetPlatforms,
            items: [
                WhatsNewItem(
                    id: .whatsNewValidationIntro,
                    title: "Native release notes",
                    body: "A user-facing change.",
                    icon: .sfSymbol(.checkmark)
                ),
            ]
        )
    }
}
