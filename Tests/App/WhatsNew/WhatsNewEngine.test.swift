@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct WhatsNewEngineTests {
    private let seenWhatsNewReleaseIDsKey = "seenWhatsNewReleaseIDs"

    @Test func releaseToShowReturnsReleaseMatchingCurrentVersionAndPlatform() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone, .iPad]
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPad },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == release)
    }

    @Test func releaseToShowReturnsNilWhenNoReleaseIsConfigured() {
        let engine = WhatsNewEngine(
            release: nil,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func releaseToShowReturnsNilWhenReleaseVersionDoesNotMatchCurrentVersion() {
        let release = Self.release(
            version: .init(major: 2026, minor: 7, patch: 0),
            targetPlatforms: [.iPhone]
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func releaseToShowTracksSeenStateByReleaseID() {
        let release = Self.release(
            id: WhatsNewReleaseId("drop-old-os"),
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone]
        )

        var queriedReleaseID: String?
        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            hasSeenRelease: {
                queriedReleaseID = $0
                return $0 == "drop-old-os"
            }
        )

        #expect(engine.releaseToShow() == nil)
        #expect(queriedReleaseID == "drop-old-os")
    }

    @Test func releaseToShowReturnsNilWhenPlatformDoesNotMatch() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.mac]
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func latestReleaseReturnsReleaseForCurrentPlatformIgnoringSeenState() {
        let release = Self.release(
            version: .init(major: 2026, minor: 7, patch: 0),
            targetPlatforms: [.iPhone, .iPad]
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 7, patch: 0) },
            currentPlatform: { .iPad },
            hasSeenRelease: { _ in true }
        )

        #expect(engine.latestRelease() == release)
    }

    @Test func latestReleaseReturnsNilWhenPlatformDoesNotMatch() {
        let release = Self.release(
            version: .init(major: 2026, minor: 7, patch: 0),
            targetPlatforms: [.mac]
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 7, patch: 0) },
            currentPlatform: { .iPad },
            hasSeenRelease: { _ in true }
        )

        #expect(engine.latestRelease() == nil)
    }

    @Test func appVersionUsesMajorMinorPatchComparisonAndDefaultsMissingComponentsToZero() {
        let majorOnlyVersion = WhatsNewAppVersion(Version(major: 2026))
        let patchVersion = WhatsNewAppVersion(Version(major: 2026, minor: 6, patch: 1))

        #expect(majorOnlyVersion == WhatsNewAppVersion(major: 2026, minor: 0, patch: 0))
        #expect(WhatsNewAppVersion(major: 2026, minor: 6, patch: 0) < patchVersion)
        #expect(patchVersion.description == "2026.6.1")
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

    @Test func releaseToShowReturnsReleaseWhenOSVersionSatisfiesRequirement() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone, .iPad],
            osRequirements: WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26)))
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            currentOSVersion: { WhatsNewOSVersion(major: 26, minor: 1) },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == release)
    }

    @Test func releaseToShowReturnsNilWhenOSVersionIsBelowMinimum() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone],
            osRequirements: WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26)))
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            currentOSVersion: { WhatsNewOSVersion(major: 18, minor: 4) },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func releaseToShowReturnsNilWhenOSVersionIsAboveMaximum() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone],
            osRequirements: WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(maximum: WhatsNewOSVersion(major: 18)))
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPhone },
            currentOSVersion: { WhatsNewOSVersion(major: 26) },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func releaseToShowAppliesIOSRequirementToIPhoneAndIPadButNotMac() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.iPhone, .iPad, .mac],
            osRequirements: WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26)))
        )

        // Mac is unconstrained by the iOS requirement, so an older macOS still matches.
        let macEngine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .mac },
            currentOSVersion: { WhatsNewOSVersion(major: 15) },
            hasSeenRelease: { _ in false }
        )
        #expect(macEngine.releaseToShow() == release)

        // iPad below the iOS minimum is filtered out.
        let iPadEngine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .iPad },
            currentOSVersion: { WhatsNewOSVersion(major: 18) },
            hasSeenRelease: { _ in false }
        )
        #expect(iPadEngine.releaseToShow() == nil)
    }

    @Test func releaseToShowAppliesMacOSRequirementToMacOnly() {
        let release = Self.release(
            version: .init(major: 2026, minor: 6, patch: 0),
            targetPlatforms: [.mac],
            osRequirements: WhatsNewOSRequirements(macOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 15)))
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentPlatform: { .mac },
            currentOSVersion: { WhatsNewOSVersion(major: 14, minor: 6) },
            hasSeenRelease: { _ in false }
        )

        #expect(engine.releaseToShow() == nil)
    }

    @Test func latestReleaseReturnsNilWhenCurrentOSCannotShowRelease() {
        let release = Self.release(
            version: .init(major: 2026, minor: 7, patch: 0),
            targetPlatforms: [.iPhone],
            osRequirements: WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26)))
        )

        let engine = WhatsNewEngine(
            release: release,
            currentVersion: { Version(major: 2026, minor: 7, patch: 0) },
            currentPlatform: { .iPhone },
            currentOSVersion: { WhatsNewOSVersion(major: 18) },
            hasSeenRelease: { _ in true }
        )

        #expect(engine.latestRelease() == nil)
    }

    @Test func versionRangeContainsRespectsInclusiveBounds() {
        let range = WhatsNewOSVersionRange(
            minimum: WhatsNewOSVersion(major: 18, minor: 1),
            maximum: WhatsNewOSVersion(major: 26)
        )

        #expect(!range.contains(WhatsNewOSVersion(major: 18, minor: 0)))
        #expect(range.contains(WhatsNewOSVersion(major: 18, minor: 1)))
        #expect(range.contains(WhatsNewOSVersion(major: 26)))
        #expect(!range.contains(WhatsNewOSVersion(major: 26, minor: 1)))
    }

    private static func release(
        id: WhatsNewReleaseId = WhatsNewReleaseId("test-release"),
        version: WhatsNewAppVersion,
        targetPlatforms: [WhatsNewTargetPlatform],
        osRequirements: WhatsNewOSRequirements? = nil
    ) -> WhatsNewRelease {
        WhatsNewRelease(
            id: id,
            version: version,
            targetPlatforms: targetPlatforms,
            osRequirements: osRequirements,
            items: [
                WhatsNewItem(
                    id: "whatsNewValidationIntro",
                    title: "Native release notes",
                    body: "A user-facing change.",
                    icon: .sfSymbol(.checkmark)
                ),
            ]
        )
    }
}
