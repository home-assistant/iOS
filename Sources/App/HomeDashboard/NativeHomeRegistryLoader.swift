import Foundation
import HAKit
import Shared

/// Gathers everything ``HomeDashboardStrategy`` needs about a server into one value: the four
/// registries the app already keeps, the panels it knows about, and the states the connection is
/// caching.
///
/// Reads rather than fetches wherever it can — areas and floors come over the WebSocket, but the
/// entity and device registries are already in the local database, so opening the native home does
/// not wait on the network for them.
enum NativeHomeRegistryLoader {
    static func load(
        server: Server,
        states: [String: HAEntity],
        isAdmin: Bool,
        userName: String?,
        hasEnergyData: Bool
    ) async -> HomeRegistry {
        let serverId = server.identifier.rawValue
        _ = await Current.areasProvider().fetchAreasAndItsEntities(for: server)

        return HomeRegistry(
            areas: (Current.areasProvider().areas[serverId] ?? []).map(homeArea),
            floors: (Current.areasProvider().floors[serverId] ?? []).map(homeFloor),
            devices: devices(serverId: serverId),
            entities: entities(serverId: serverId),
            states: states.values.map(homeState).sorted { $0.id < $1.id },
            panels: panels(serverId: serverId),
            isAdmin: isAdmin,
            userName: userName,
            hasEnergyData: hasEnergyData
        )
    }

    // MARK: - Registries

    private static func homeArea(_ area: HAAreasRegistryResponse) -> HomeArea {
        HomeArea(
            id: area.areaId,
            name: area.name,
            icon: area.icon,
            floorId: area.floorId,
            picture: area.picture,
            temperatureEntityId: area.temperatureEntityId,
            humidityEntityId: area.humidityEntityId
        )
    }

    private static func homeFloor(_ floor: HAFloorRegistryResponse) -> HomeFloor {
        HomeFloor(id: floor.floorId, name: floor.name, icon: floor.icon, level: floor.level)
    }

    private static func devices(serverId: String) -> [HomeDevice] {
        do {
            return try AppDeviceRegistry.config(serverId: serverId).map { device in
                HomeDevice(
                    id: device.deviceId,
                    name: device.name,
                    nameByUser: device.nameByUser,
                    areaId: device.areaId
                )
            }
        } catch {
            Current.Log.error("Native home failed to read the device registry: \(error.localizedDescription)")
            return []
        }
    }

    private static func entities(serverId: String) -> [HomeEntityRegistration] {
        do {
            return try EntityRegistryListForDisplay.Entity.config(serverId: serverId).map { entity in
                HomeEntityRegistration(
                    id: entity.entityId,
                    platform: entity.platform,
                    deviceId: entity.deviceId,
                    areaId: entity.areaId,
                    name: entity.name,
                    // The registry stores the category as an index into a table the app does not
                    // persist. Which category it is never changes what the dashboard does — only
                    // whether there is one at all, which is what "primary entity" means.
                    entityCategory: entity.entityCategory == nil ? nil : .config,
                    isHidden: entity.hidden ?? false,
                    labels: entity.labels ?? [],
                    icon: entity.icon
                )
            }
        } catch {
            Current.Log.error("Native home failed to read the entity registry: \(error.localizedDescription)")
            return []
        }
    }

    private static func panels(serverId: String) -> Set<String> {
        do {
            return try Set((AppPanel.panels(serverId: serverId) ?? []).map(\.component))
        } catch {
            Current.Log.error("Native home failed to read the panels: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - States

    static func homeState(_ entity: HAEntity) -> HomeEntityState {
        let attributes = entity.attributes.dictionary
        return HomeEntityState(
            id: entity.entityId,
            state: entity.state,
            attributes: HomeEntityAttributes(
                friendlyName: attributes["friendly_name"] as? String,
                deviceClass: attributes["device_class"] as? String,
                icon: entity.attributes.icon,
                unitOfMeasurement: attributes["unit_of_measurement"] as? String,
                supportedFeatures: attributes["supported_features"] as? Int,
                brightness: attributes["brightness"] as? Int,
                currentTemperature: attributes["current_temperature"] as? Double,
                targetTemperature: attributes["temperature"] as? Double,
                hvacAction: attributes["hvac_action"] as? String,
                mediaTitle: attributes["media_title"] as? String,
                supportedColorModes: attributes["supported_color_modes"] as? [String]
            )
        )
    }
}
