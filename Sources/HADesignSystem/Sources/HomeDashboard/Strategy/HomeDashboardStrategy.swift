import Foundation

/// Turns a server's registries into the same dashboard the web frontend builds from them: the
/// overview first, then one view per area. The port of the frontend's `home-dashboard-strategy`,
/// and the entry point to the translator.
///
/// A pure function of its input, deliberately: give it the same registries the browser has and it
/// produces the same screens, which is what makes the native home testable without a server and
/// comparable against the web one.
public enum HomeDashboardStrategy {
    public static func generate(
        config: HomeDashboardStrategyConfig = HomeDashboardStrategyConfig(),
        registry: HomeRegistry,
        strings: HomeDashboardStrings = .preview
    ) -> HomeDashboardConfig {
        switch registry.serverState {
        case .starting:
            return HomeDashboardConfig(views: [
                HomeDashboardViewConfig(
                    path: HomeDashboardPath.overview,
                    content: .panel([.emptyState(HomeEmptyStateCardConfig(
                        icon: "mdi:home-assistant",
                        title: strings.startingTitle,
                        content: strings.startingContent
                    ))])
                ),
            ])
        case .recovery:
            return HomeDashboardConfig(views: [
                HomeDashboardViewConfig(
                    path: HomeDashboardPath.overview,
                    content: .panel([.emptyState(HomeEmptyStateCardConfig(
                        icon: "mdi:hammer-wrench",
                        title: strings.recoveryModeTitle,
                        content: strings.recoveryModeContent
                    ))])
                ),
            ])
        case .running:
            break
        }

        let overview = HomeOverviewStrategy.generate(config: config, registry: registry, strings: strings)
        let areaViews = registry.areas.compactMap { area in
            HomeAreaStrategy.generate(areaId: area.id, config: config, registry: registry, strings: strings)
        }
        let mediaPlayers = HomeMediaPlayersStrategy.generate(registry: registry, strings: strings)
        let otherDevices = HomeOtherDevicesStrategy.generate(config: config, registry: registry, strings: strings)
        return HomeDashboardConfig(views: [overview] + areaViews + [mediaPlayers, otherDevices])
    }
}
