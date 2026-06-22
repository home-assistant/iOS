import Shared
import Version

final class WhatsNewEngine {
    private let release: WhatsNewRelease?
    private let currentVersion: () -> Version
    private let currentPlatform: () -> WhatsNewTargetPlatform
    private let currentOSVersion: () -> WhatsNewOSVersion
    private let hasSeenRelease: (String) -> Bool

    init(
        release: WhatsNewRelease? = WhatsNewCatalog.release,
        currentVersion: @escaping () -> Version = Current.clientVersion,
        currentPlatform: @escaping () -> WhatsNewTargetPlatform = { .current },
        currentOSVersion: @escaping () -> WhatsNewOSVersion = { .current },
        hasSeenRelease: @escaping (String) -> Bool = { Current.settingsStore.hasSeenWhatsNew(releaseID: $0) }
    ) {
        self.release = release
        self.currentVersion = currentVersion
        self.currentPlatform = currentPlatform
        self.currentOSVersion = currentOSVersion
        self.hasSeenRelease = hasSeenRelease
    }

    func releaseToShow() -> WhatsNewRelease? {
        guard let release else { return nil }
        let appVersion = WhatsNewAppVersion(currentVersion())
        let platform = currentPlatform()
        let osVersion = currentOSVersion()

        guard release.version == appVersion,
              release.matches(platform: platform, osVersion: osVersion),
              !hasSeenRelease(release.releaseID) else {
            return nil
        }

        return release
    }

    func latestRelease() -> WhatsNewRelease? {
        guard let release else { return nil }
        let platform = currentPlatform()
        let osVersion = currentOSVersion()
        return release.matches(platform: platform, osVersion: osVersion) ? release : nil
    }

    func markSeen(_ release: WhatsNewRelease) {
        Current.settingsStore.markWhatsNewSeen(releaseID: release.releaseID)
    }
}
