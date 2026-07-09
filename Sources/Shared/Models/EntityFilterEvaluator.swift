import Foundation
import HAKit

public struct EntityFilterEvaluator {
    public struct ResolvedEntity: Sendable {
        public let areaId: String?
        public let deviceId: String?
        public let category: EntityCategory
        public let hidden: Bool
        public let labels: [String]
        public let platform: String?
    }

    public let states: [String: HAEntity]
    private let entities: [String: ResolvedEntity]
    private let deviceAreas: [String: String?]
    private let areaFloors: [String: String?]
    private let floorIds: Set<String>
    private let entitiesByDevice: [String: [String]]

    public init(
        states: [String: HAEntity],
        entityRegistry: EntityRegistryListForDisplay,
        devices: [DeviceRegistryEntry],
        areas: [HAAreasRegistryResponse],
        floors: [HAFloorRegistryResponse]
    ) {
        self.states = states

        var resolved: [String: ResolvedEntity] = [:]
        var byDevice: [String: [String]] = [:]
        for entity in entityRegistry.entities {
            resolved[entity.entityId] = ResolvedEntity(
                areaId: entity.areaId,
                deviceId: entity.deviceId,
                category: Self.category(for: entity.entityCategory, in: entityRegistry.entityCategories),
                hidden: entity.isHidden,
                labels: entity.labels ?? [],
                platform: entity.platform
            )
            if let deviceId = entity.deviceId {
                byDevice[deviceId, default: []].append(entity.entityId)
            }
        }
        self.entities = resolved
        self.entitiesByDevice = byDevice
        self.deviceAreas = Dictionary(devices.map { ($0.id, $0.areaId) }, uniquingKeysWith: { first, _ in first })
        self.areaFloors = Dictionary(areas.map { ($0.areaId, $0.floorId) }, uniquingKeysWith: { first, _ in first })
        self.floorIds = Set(floors.map(\.floorId))
    }

    private static func category(for index: Int?, in categories: [String: String]) -> EntityCategory {
        guard let index, let name = categories[String(index)] else { return .none }
        return EntityCategory(rawValue: name) ?? .none
    }

    public var entityIds: [String] { Array(states.keys) }

    public func deviceClass(of entityId: String) -> String {
        states[entityId]?.attributes.dictionary["device_class"] as? String ?? "none"
    }

    public func findEntities(matching filters: [EntityFilter]) -> [String] {
        let ids = entityIds
        var seen = Set<String>()
        var results: [String] = []
        for filter in filters {
            for id in ids where !seen.contains(id) && matches(entityId: id, filter: filter) {
                seen.insert(id)
                results.append(id)
            }
        }
        return results
    }

    public func matches(entityId: String, filter: EntityFilter) -> Bool {
        guard states[entityId] != nil else { return false }
        guard passesDomain(Self.domain(of: entityId), filter: filter) else { return false }
        guard passesDeviceClass(entityId: entityId, filter: filter) else { return false }
        return passesContext(entityId: entityId, filter: filter)
    }

    private func passesDomain(_ domain: String, filter: EntityFilter) -> Bool {
        if let domains = filter.domain, !domains.contains(domain) { return false }
        if let hiddenDomains = filter.hiddenDomains, hiddenDomains.contains(domain) { return false }
        return true
    }

    private func passesDeviceClass(entityId: String, filter: EntityFilter) -> Bool {
        guard let deviceClasses = filter.deviceClass else { return true }
        return deviceClasses.contains(deviceClass(of: entityId))
    }

    private func passesContext(entityId: String, filter: EntityFilter) -> Bool {
        let resolved = entities[entityId]
        if resolved?.hidden == true { return false }
        let areaId = resolveAreaId(for: resolved)
        let floorId = resolveFloorId(forArea: areaId)
        guard passesLocation(resolved: resolved, areaId: areaId, floorId: floorId, filter: filter) else {
            return false
        }
        return passesMetadata(resolved: resolved, filter: filter)
    }

    private func passesLocation(
        resolved: ResolvedEntity?,
        areaId: String?,
        floorId: String?,
        filter: EntityFilter
    ) -> Bool {
        if let floors = filter.floor, !floors.contains(floorId) { return false }
        if let areas = filter.area, !areas.contains(areaId) { return false }
        if let devices = filter.device, !devices.contains(resolved?.deviceId) { return false }
        return true
    }

    private func passesMetadata(resolved: ResolvedEntity?, filter: EntityFilter) -> Bool {
        if let labels = filter.label {
            guard let resolved, resolved.labels.contains(where: labels.contains) else { return false }
        }
        if let categories = filter.entityCategory, !categories.contains(resolved?.category ?? .none) {
            return false
        }
        return passesHiddenPlatform(resolved: resolved, filter: filter)
    }

    private func passesHiddenPlatform(resolved: ResolvedEntity?, filter: EntityFilter) -> Bool {
        guard let hiddenPlatforms = filter.hiddenPlatform else { return true }
        guard let resolved else { return false }
        if let platform = resolved.platform, hiddenPlatforms.contains(platform) { return false }
        return true
    }

    private func resolveAreaId(for resolved: ResolvedEntity?) -> String? {
        if let areaId = resolved?.areaId { return areaId }
        if let deviceId = resolved?.deviceId { return deviceAreas[deviceId] ?? nil }
        return nil
    }

    private func resolveFloorId(forArea areaId: String?) -> String? {
        guard let areaId, let floorId = areaFloors[areaId] ?? nil, floorIds.contains(floorId) else {
            return nil
        }
        return floorId
    }

    public func isLowBattery(entityId: String, threshold: Double = 20) -> Bool {
        guard let state = states[entityId]?.state else { return false }
        if Self.domain(of: entityId) == Domain.binarySensor.rawValue {
            return state == "on"
        }
        if isBatteryCharging(entityId: entityId) { return false }
        guard let value = Double(state) else { return false }
        return value <= threshold
    }

    private func isBatteryCharging(entityId: String) -> Bool {
        guard let deviceId = entities[entityId]?.deviceId, let siblings = entitiesByDevice[deviceId] else {
            return false
        }
        return siblings.contains { deviceClass(of: $0) == "battery_charging" && states[$0]?.state == "on" }
    }

    private static func domain(of entityId: String) -> String {
        String(entityId.split(separator: ".", maxSplits: 1).first ?? "")
    }
}
