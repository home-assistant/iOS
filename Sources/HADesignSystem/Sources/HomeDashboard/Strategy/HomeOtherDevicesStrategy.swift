import Foundation

/// The devices that belong to no room, a list per device. The port of the frontend's
/// `home-other-devices-view-strategy` — the view the overview's "Devices" tile opens.
public enum HomeOtherDevicesStrategy {
    public static func generate(
        config: HomeDashboardStrategyConfig,
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> HomeDashboardViewConfig {
        let candidates = HomeEntityFilterMatcher.find(
            in: registry.allEntityIds,
            matching: HomeOtherDevicesFilters.filters,
            registry: registry
        )
        let primary = HomeEntityFilter(entityCategories: [.none])

        var byDevice: [String: [String]] = [:]
        var deviceOrder: [String] = []
        for entityId in candidates {
            // Only entities that belong to a device: a stray entity with no device is not something
            // this view can offer to file away.
            guard let device = registry.context(of: entityId).device else {
                continue
            }
            if byDevice[device.id] == nil {
                deviceOrder.append(device.id)
            }
            byDevice[device.id, default: []].append(entityId)
        }

        var sections: [HomeDashboardSectionConfig] = []
        for deviceId in deviceOrder {
            let entities = (byDevice[deviceId] ?? []).filter {
                HomeEntityFilterMatcher.matches(entityId: $0, filter: primary, registry: registry)
            }
            guard !entities.isEmpty, let device = registry.device(deviceId) else {
                continue
            }
            sections.append(HomeDashboardSectionConfig(
                id: "device:\(deviceId)",
                cards: [
                    .heading(.init(
                        id: "device:\(deviceId)",
                        heading: device.displayName ?? strings.unnamedDevice,
                        tapAction: registry.isAdmin ? .navigate("/config/devices/device/\(deviceId)") : nil
                    )),
                    .entities(HomeEntitiesCardConfig(id: deviceId, entityIds: entities)),
                ]
            ))
        }

        guard !sections.isEmpty else {
            return HomeDashboardViewConfig(
                path: HomeDashboardPath.otherDevices,
                title: strings.devices,
                icon: "mdi:devices",
                isSubview: true,
                content: .panel([.emptyState(HomeEmptyStateCardConfig(
                    icon: "mdi:check-all",
                    title: strings.allOrganizedTitle,
                    content: strings.allOrganizedContent
                ))])
            )
        }

        return HomeDashboardViewConfig(
            path: HomeDashboardPath.otherDevices,
            title: strings.devices,
            icon: "mdi:devices",
            isSubview: true,
            content: .sections(sections),
            maxColumns: min(max(sections.count, 2), 3)
        )
    }
}
