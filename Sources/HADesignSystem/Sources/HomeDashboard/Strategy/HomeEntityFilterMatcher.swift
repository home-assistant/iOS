import Foundation

/// Runs ``HomeEntityFilter``s against a ``HomeRegistry``. The port of the frontend's
/// `generateEntityFilter` and `findEntities`.
public enum HomeEntityFilterMatcher {
    /// Whether one entity satisfies one filter. The order of the checks follows the frontend's, so a
    /// filter that is wrong here is wrong there too.
    public static func matches(entityId: String, filter: HomeEntityFilter, registry: HomeRegistry) -> Bool {
        guard let state = registry.state(entityId) else {
            return false
        }
        guard matchesDomain(entityId: entityId, filter: filter),
              matchesDeviceClass(state: state, filter: filter) else {
            return false
        }
        return matchesContext(registry.context(of: entityId), filter: filter)
    }

    private static func matchesDomain(entityId: String, filter: HomeEntityFilter) -> Bool {
        guard filter.domains != nil || filter.hiddenDomains != nil else {
            return true
        }
        let domain = HomeEntityID.domain(of: entityId)
        if let domains = filter.domains, !domains.contains(domain) {
            return false
        }
        if let hiddenDomains = filter.hiddenDomains, hiddenDomains.contains(domain) {
            return false
        }
        return true
    }

    private static func matchesDeviceClass(state: HomeEntityState, filter: HomeEntityFilter) -> Bool {
        guard let deviceClasses = filter.deviceClasses else {
            return true
        }
        // An entity with no device class answers to `"none"`, which is how the climate filter picks
        // up a plain cover.
        return deviceClasses.contains(state.attributes.deviceClass ?? "none")
    }

    /// Everything the filter asks about the entity's place in the home, and about the registry entry
    /// itself.
    private static func matchesContext(_ context: HomeEntityContext, filter: HomeEntityFilter) -> Bool {
        // A hidden entity is out whatever else matched — the user said so.
        if context.entity?.isHidden == true {
            return false
        }
        if let floors = filter.floors, !floors.contains(context.floor?.id) {
            return false
        }
        if let areas = filter.areas, !areas.contains(context.area?.id) {
            return false
        }
        if let devices = filter.devices, !devices.contains(context.device?.id) {
            return false
        }
        if let categories = filter.entityCategories,
           !categories.contains(HomeEntityCategoryFilter.of(context.entity?.entityCategory)) {
            return false
        }
        return matchesRegistration(context.entity, filter: filter)
    }

    /// The two checks that need a registry entry at all: an entity the registry has never heard of
    /// carries neither labels nor a platform, so it cannot satisfy either.
    private static func matchesRegistration(_ entity: HomeEntityRegistration?, filter: HomeEntityFilter) -> Bool {
        if let labels = filter.labels {
            guard let entity, entity.labels.contains(where: labels.contains) else {
                return false
            }
        }
        if let hiddenPlatforms = filter.hiddenPlatforms {
            guard let entity else {
                return false
            }
            if let platform = entity.platform, hiddenPlatforms.contains(platform) {
                return false
            }
        }
        return true
    }

    /// The entities matching any of the filters, each appearing once, filters applied in order.
    ///
    /// The order matters and is the frontend's: the first filter's matches come first, in the order
    /// the entities were given, then the second filter's, and so on. It is what puts a section's
    /// tiles in the order the web dashboard puts them in.
    public static func find(
        in entityIds: [String],
        matching filters: [HomeEntityFilter],
        registry: HomeRegistry
    ) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        for filter in filters {
            for entityId in entityIds where !seen.contains(entityId) {
                if matches(entityId: entityId, filter: filter, registry: registry) {
                    seen.insert(entityId)
                    results.append(entityId)
                }
            }
        }
        return results
    }
}
