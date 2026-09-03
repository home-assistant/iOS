import Shared

final class WhatsNewEngine {
    private let releases: [WhatsNewRelease]
    private let currentVersion: () -> Version
    private let currentPlatform: () -> WhatsNewTargetPlatform
    private let currentOSVersion: () -> WhatsNewOSVersion
    private let hasSeenRelease: (String) -> Bool

    init(
        releases: [WhatsNewRelease] = WhatsNewCatalog.releases,
        currentVersion: @escaping () -> Version = Current.clientVersion,
        currentPlatform: @escaping () -> WhatsNewTargetPlatform = { .current },
        currentOSVersion: @escaping () -> WhatsNewOSVersion = { .current },
        hasSeenRelease: @escaping (String) -> Bool = { Current.settingsStore.hasSeenWhatsNew(releaseID: $0) }
    ) {
        self.releases = releases
        self.currentVersion = currentVersion
        self.currentPlatform = currentPlatform
        self.currentOSVersion = currentOSVersion
        self.hasSeenRelease = hasSeenRelease
    }

    /// The first catalog release, in catalog order, that this device has not seen yet and that targets the
    /// running app version, platform, and OS version.
    func releaseToShow() -> WhatsNewRelease? {
        let appVersion = WhatsNewAppVersion(currentVersion())
        let platform = currentPlatform()
        let osVersion = currentOSVersion()

        return releases.first { release in
            release.version == appVersion
                && release.matches(platform: platform, osVersion: osVersion)
                && !hasSeenRelease(release.id.rawValue)
        }
    }

    /// The highest-versioned catalog release this device can show, whether or not it has been seen.
    /// Ties keep catalog order.
    func latestRelease() -> WhatsNewRelease? {
        let platform = currentPlatform()
        let osVersion = currentOSVersion()
        return releases
            .filter { $0.matches(platform: platform, osVersion: osVersion) }
            .max { $0.version < $1.version }
    }

    func markSeen(_ release: WhatsNewRelease) {
        Current.settingsStore.markWhatsNewSeen(releaseID: release.id.rawValue)
    }
}
