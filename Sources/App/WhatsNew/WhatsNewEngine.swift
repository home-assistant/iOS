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

    /// The highest-versioned catalog release this device can show, whether or not it has been seen. When
    /// several share that version, the first in catalog order wins.
    func latestRelease() -> WhatsNewRelease? {
        let platform = currentPlatform()
        let osVersion = currentOSVersion()
        var latest: WhatsNewRelease?
        for release in releases where release.matches(platform: platform, osVersion: osVersion) {
            if let current = latest, release.version <= current.version {
                continue
            }
            latest = release
        }
        return latest
    }

    func markSeen(_ release: WhatsNewRelease) {
        Current.settingsStore.markWhatsNewSeen(releaseID: release.id.rawValue)
    }
}
