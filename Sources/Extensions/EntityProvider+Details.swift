import Foundation
import GRDB

/// Builds the secondary "context" line (e.g. `Area • Device`, optionally prefixed with the server
/// name) shown under an entity name in pickers and configuration screens.
///
/// This is the single source of truth shared by the in-app `EntityPicker`, every AppIntent based
/// picker (widgets, controls, App Shortcuts) and the Watch/Widgets/CarPlay/App-Icon configuration
/// screens, so the context shown stays consistent across the whole app, matching how Home Assistant
/// core/frontend present entities.
public enum EntityContextSubtitle {
    /// - Parameters:
    ///   - serverName: The server the entity belongs to. Pass this only when more than one server is
    ///     configured — it's prepended as the first segment; pass `nil` to omit it (single-server).
    ///   - floorName: The floor the entity's area belongs to. Pass this only when it's needed to
    ///     disambiguate two areas that share the same name; pass `nil` to omit it otherwise.
    ///   - areaName: The area the entity belongs to, if any.
    ///   - deviceName: The device the entity belongs to, if any. Omitted when it merely repeats the entity name.
    ///   - entityName: The entity's resolved display name (used to avoid echoing it as the device name).
    ///   - entityId: The entity id, used as a last-resort context when no other context is available.
    ///   - domain: The entity's domain. Used to decide whether the entity id fallback is meaningful.
    ///   - fallbackToEntityId: When `true`, returns the entity id if no other context exists.
    /// - Returns: The context line (e.g. `Home • Living Room • Thermostat`), or `nil` when there's
    ///   nothing meaningful to show (so callers can omit the subtitle entirely — e.g. a
    ///   script/scene/automation with no server/area/device context).
    public static func make(
        serverName: String? = nil,
        floorName: String? = nil,
        areaName: String?,
        deviceName: String?,
        entityName: String,
        entityId: String,
        domain: Domain?,
        fallbackToEntityId: Bool = true
    ) -> String? {
        var parts: [String] = []
        if let serverName, !serverName.isEmpty {
            parts.append(serverName)
        }
        if let floorName, !floorName.isEmpty {
            parts.append(floorName)
        }
        if let areaName, !areaName.isEmpty {
            parts.append(areaName)
        }
        if let deviceName, !deviceName.isEmpty,
           deviceName.range(of: entityName, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
            parts.append(deviceName)
        }
        guard parts.isEmpty else {
            return parts.joined(separator: " • ")
        }
        // No area/device context available.
        if let domain, [.script, .scene, .automation].contains(domain) {
            return nil
        }
        // Fall back to the entity id, but only when it carries something to show — placeholders and
        // pending-configuration entities pass an empty id, which would otherwise render a blank line.
        guard fallbackToEntityId, !entityId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return entityId
    }
}

/// A type that carries enough about an entity to render the shared context line (`Area • Device`).
///
/// Conformers get `contextSubtitle` for free, so every AppIntent entity / picker row produces the
/// exact same context — there's no per-type reimplementation to drift out of sync. The formatting
/// itself still lives in `EntityContextSubtitle.make` (the single source of truth); this protocol is
/// just the shared, hard-to-get-wrong way to call it.
public protocol EntityContextRepresentable {
    /// The entity id (e.g. `light.kitchen`). Also used to derive the domain.
    var entityId: String { get }
    /// The entity's resolved display name.
    var displayString: String { get }
    /// The area the entity belongs to, if known.
    var areaName: String? { get }
    /// The device the entity belongs to, if known.
    var deviceName: String? { get }
    /// The floor the entity's area belongs to, set only when it's needed to disambiguate two areas
    /// that share the same name. Defaults to `nil` so most conformers don't need to provide it.
    var floorName: String? { get }
}

public extension EntityContextRepresentable {
    var floorName: String? { nil }

    /// The shared `Floor • Area • Device` context line for this entity. See `EntityContextSubtitle.make`.
    var contextSubtitle: String? {
        EntityContextSubtitle.make(
            floorName: floorName,
            areaName: areaName,
            deviceName: deviceName,
            entityName: displayString,
            entityId: entityId,
            domain: Domain(entityId: entityId)
        )
    }
}

public extension HAAppEntity {
    var area: AppArea? {
        do {
            let areas = try AppArea.fetchAreas(for: serverId)

            return areas.first { area in
                area.entities.contains(entityId)
            }
        } catch {
            Current.Log.error("Failed to fetch areas for entity \(entityId): \(error)")
            return nil
        }
    }

    var device: AppDeviceRegistry? {
        do {
            let entityRegistry = try Current.database().read { db in
                try EntityRegistryListForDisplay.Entity
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.entityId.rawValue) == entityId)
                    .fetchOne(db)
            }
            let deviceId = entityRegistry?.deviceId
            let device = try Current.database().read { db in
                try AppDeviceRegistry
                    .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.DeviceRegistry.deviceId.rawValue) == deviceId)
                    .fetchOne(db)
            }
            return device
        } catch {
            Current.Log.error("Failed to fetch device for entity \(entityId): \(error)")
            return nil
        }
    }

    /// The secondary context line shown under the entity name (`Floor • Area • Device`).
    var contextualSubtitle: String? {
        let allAreas = (try? AppArea.fetchAreas(for: serverId)) ?? []
        let entityArea = allAreas.first { $0.entities.contains(entityId) }
        let floorName = entityArea.flatMap { area in
            allAreas.disambiguatingFloorName(for: area)
        }
        return EntityContextSubtitle.make(
            floorName: floorName,
            areaName: entityArea?.name,
            deviceName: device?.name,
            entityName: name,
            entityId: entityId,
            domain: Domain(rawValue: domain)
        )
    }
}

public extension [AppArea] {
    /// The normalized set of area names that occur in more than one area, i.e. the names that are
    /// ambiguous on their own and need the floor to tell them apart.
    func duplicatedAreaNames() -> Set<String> {
        var counts: [String: Int] = [:]
        for area in self {
            counts[area.name.normalizedForAreaComparison, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    /// The floor name to display for `area`, but only when its name collides with another area on the
    /// same server (so the floor disambiguates them). Returns `nil` when the area name is unique or has
    /// no floor.
    func disambiguatingFloorName(for area: AppArea) -> String? {
        guard let floorName = area.floorName, !floorName.isEmpty,
              duplicatedAreaNames().contains(area.name.normalizedForAreaComparison) else {
            return nil
        }
        return floorName
    }
}

private extension String {
    /// Case- and diacritic-insensitive, whitespace-trimmed form used to compare area names so that
    /// "Bedroom" and "bedroom " count as the same name when detecting collisions.
    var normalizedForAreaComparison: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension [HAAppEntity] {
    /// Creates a mapping from entity IDs to their associated areas for a given server.
    /// - Parameter serverId: The server identifier to filter areas by.
    /// - Returns: A dictionary mapping entity IDs to their corresponding `AppArea` objects.
    func areasMap(for serverId: String) -> [String: AppArea] {
        do {
            let areas = try AppArea.fetchAreas(for: serverId)

            var entityToAreaMap: [String: AppArea] = [:]

            // Iterate through areas and map each entity to its area
            for area in areas {
                for entityId in area.entities {
                    entityToAreaMap[entityId] = area
                }
            }

            return entityToAreaMap
        } catch {
            Current.Log.error("Failed to fetch areas for mapping: \(error)")
            return [:]
        }
    }

    /// Creates a mapping from entity IDs to the floor name that disambiguates their area, for a given
    /// server. Only entities whose area name collides with another area on the same server are present
    /// — for everything else the floor is omitted (so callers pass `nil`). Mirrors `areasMap`.
    /// - Parameter serverId: The server identifier to filter areas by.
    /// - Returns: A dictionary mapping entity IDs to their disambiguating floor name.
    func floorNamesMap(for serverId: String) -> [String: String] {
        do {
            let areas = try AppArea.fetchAreas(for: serverId)
            let duplicated = areas.duplicatedAreaNames()
            var entityToFloorMap: [String: String] = [:]
            for area in areas {
                guard let floorName = area.floorName, !floorName.isEmpty,
                      duplicated.contains(area.name.normalizedForAreaComparison) else {
                    continue
                }
                for entityId in area.entities {
                    entityToFloorMap[entityId] = floorName
                }
            }
            return entityToFloorMap
        } catch {
            Current.Log.error("Failed to fetch areas for floor mapping: \(error)")
            return [:]
        }
    }

    /// Creates a mapping from entity IDs to their associated devices for a given server.
    /// - Parameter serverId: The server identifier to filter entities and devices by.
    /// - Returns: A dictionary mapping entity IDs to their corresponding `AppDeviceRegistry` objects.
    func devicesMap(for serverId: String) -> [String: AppDeviceRegistry] {
        do {
            // Fetch all entity registries for the server
            let entityRegistries = try Current.database().read { db in
                try EntityRegistryListForDisplay.Entity
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }

            // Fetch all devices for the server
            let devices = try Current.database().read { db in
                try AppDeviceRegistry
                    .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }

            // Create device lookup by deviceId
            let devicesByDeviceId = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0) })

            // Map entity IDs to devices
            var entityToDeviceMap: [String: AppDeviceRegistry] = [:]

            for entityRegistry in entityRegistries {
                guard let deviceId = entityRegistry.deviceId,
                      let device = devicesByDeviceId[deviceId] else {
                    continue
                }
                entityToDeviceMap[entityRegistry.entityId] = device
            }

            return entityToDeviceMap
        } catch {
            Current.Log.error("Failed to fetch devices for mapping: \(error)")
            return [:]
        }
    }
}
