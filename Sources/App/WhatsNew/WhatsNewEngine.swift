import Shared
import Version

final class WhatsNewEngine {
    private let releases: [WhatsNewRelease]
    private let currentVersion: () -> Version
    private let currentPlatform: () -> WhatsNewTargetPlatform
    private let hasSeenRelease: (String) -> Bool

    init(
        releases: [WhatsNewRelease] = WhatsNewCatalog.releases,
        currentVersion: @escaping () -> Version = Current.clientVersion,
        currentPlatform: @escaping () -> WhatsNewTargetPlatform = { .current },
        hasSeenRelease: @escaping (String) -> Bool = { Current.settingsStore.hasSeenWhatsNew(releaseID: $0) }
    ) {
        self.releases = releases
        self.currentVersion = currentVersion
        self.currentPlatform = currentPlatform
        self.hasSeenRelease = hasSeenRelease
    }

    func releaseToShow() -> WhatsNewRelease? {
        let appVersion = WhatsNewAppVersion(currentVersion())
        let platform = currentPlatform()

        guard let release = releases.first(where: {
            $0.version == appVersion && $0.targetPlatforms.contains(platform)
        }) else {
            return nil
        }

        guard !hasSeenRelease(release.releaseID) else {
            return nil
        }

        return release
    }

    func latestRelease() -> WhatsNewRelease? {
        let platform = currentPlatform()
        return releases
            .filter { $0.targetPlatforms.contains(platform) }
            .max(by: { $0.version < $1.version })
    }

    func markSeen(_ release: WhatsNewRelease) {
        Current.settingsStore.markWhatsNewSeen(releaseID: release.releaseID)
    }
}
