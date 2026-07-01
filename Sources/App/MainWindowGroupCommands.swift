import Foundation
import Shared
import SwiftUI

/// Controls macOS and iPadOS menu bar items for the main app window.
struct MainWindowGroupCommands: Commands {
    @StateObject private var reloadObserver = MainWindowGroupCommandsReloadObserver()

    var body: some Commands {
        CommandMenu(L10n.MainWindowGroupCommands.Entities.title) {
            areasCommandMenu
                .id(reloadObserver.reloadID)
        }
    }

    @ViewBuilder
    private var areasCommandMenu: some View {
        let servers = areaCommandServers

        if servers.isEmpty {
            Text(L10n.MainWindowGroupCommands.Areas.empty)
        } else if servers.count == 1, let server = servers.first {
            areaMenus(for: server)
        } else {
            ForEach(servers) { server in
                Menu(server.name) {
                    areaMenus(for: server)
                }
            }
        }
    }

    @ViewBuilder
    private func areaMenus(for server: AreasCommandServer) -> some View {
        if server.floors.isEmpty {
            Text(L10n.MainWindowGroupCommands.Areas.empty)
        } else {
            ForEach(server.floors) { floor in
                Menu(floor.name) {
                    ForEach(floor.areas) { area in
                        Menu(area.name) {
                            deviceMenus(for: area, server: server)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func deviceMenus(for area: AreasCommandArea, server: AreasCommandServer) -> some View {
        if area.devices.isEmpty {
            Text(L10n.MainWindowGroupCommands.Entities.empty)
        } else {
            ForEach(area.devices) { device in
                Menu(device.name) {
                    domainSections(for: device, server: server)
                }
            }
        }
    }

    @ViewBuilder
    private func domainSections(for device: AreasCommandDevice, server: AreasCommandServer) -> some View {
        ForEach(device.domains) { domain in
            Section(domain.name) {
                entityButtons(domain.entities, serverId: server.id)
            }
        }
    }

    @ViewBuilder
    private func entityButtons(_ entities: [AreasCommandEntity], serverId: String) -> some View {
        ForEach(entities) { entity in
            Button(entity.name) {
                openEntity(entity.entityId, serverId: serverId)
            }
        }
    }

    private var areaCommandServers: [AreasCommandServer] {
        Current.servers.all.map { server in
            let serverId = server.identifier.rawValue
            let areas: [AppArea]
            let entities: [EntityRegistryListForDisplay.Entity]
            let devices: [AppDeviceRegistry]

            do {
                areas = try AppArea.fetchAreas(for: serverId)
                entities = try EntityRegistryListForDisplay.Entity.config(serverId: serverId)
                devices = try AppDeviceRegistry.config(serverId: serverId)
            } catch {
                Current.Log
                    .error("Failed to build Areas command menu for server \(serverId): \(error.localizedDescription)")
                return AreasCommandServer(id: serverId, name: server.info.name, floors: [])
            }

            let entitiesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.entityId, $0) })
            let devicesById = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0) })
            let commandAreas = areas.map { area in
                let areaEntities = area.entities.compactMap { entitiesById[$0] }

                return AreasCommandArea(
                    id: area.areaId,
                    name: area.name,
                    floorId: area.floorId,
                    floorName: area.floorName,
                    devices: Self.devices(from: areaEntities, devicesById: devicesById)
                )
            }

            return AreasCommandServer(
                id: serverId,
                name: server.info.name,
                floors: Self.floors(from: commandAreas)
            )
        }
    }

    private static func floors(from areas: [AreasCommandArea]) -> [AreasCommandFloor] {
        Dictionary(grouping: areas) { area in
            AreasCommandFloorKey(id: area.floorId, name: area.floorName ?? L10n.MainWindowGroupCommands.Floor.empty)
        }
        .map { floor, areas in
            AreasCommandFloor(id: floor.id ?? "no-floor", name: floor.name, areas: areas)
        }
        .sorted { lhs, rhs in
            if lhs.id == "no-floor" { return false }
            if rhs.id == "no-floor" { return true }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func devices(
        from entities: [EntityRegistryListForDisplay.Entity],
        devicesById: [String: AppDeviceRegistry]
    ) -> [AreasCommandDevice] {
        var groups: [String: (name: String, entities: [EntityRegistryListForDisplay.Entity])] = [:]

        for entity in entities {
            let deviceId = entity.deviceId.flatMap { devicesById[$0]?.deviceId } ?? "other-entities"
            let deviceName = entity.deviceId.flatMap { devicesById[$0]?.displayName } ?? L10n.MainWindowGroupCommands
                .OtherEntities.title

            if var group = groups[deviceId] {
                group.entities.append(entity)
                groups[deviceId] = group
            } else {
                groups[deviceId] = (deviceName, [entity])
            }
        }

        return groups.map { deviceId, group in
            AreasCommandDevice(
                id: deviceId,
                name: group.name,
                domains: domains(from: group.entities)
            )
        }
        .sorted { lhs, rhs in
            if lhs.id == "other-entities" { return false }
            if rhs.id == "other-entities" { return true }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func domains(from entities: [EntityRegistryListForDisplay.Entity]) -> [AreasCommandDomain] {
        Dictionary(grouping: entities, by: { domainName(for: $0.entityId) })
            .map { domainName, entities in
                AreasCommandDomain(
                    id: domainName,
                    name: localizedDomainName(for: domainName),
                    entities: sortedEntities(entities.map(commandEntity(from:)))
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func sortedEntities(_ entities: [AreasCommandEntity]) -> [AreasCommandEntity] {
        entities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func commandEntity(from entity: EntityRegistryListForDisplay.Entity) -> AreasCommandEntity {
        AreasCommandEntity(entityId: entity.entityId, name: entityName(for: entity))
    }

    private static func domainName(for entityId: String) -> String {
        entityId.split(separator: ".", maxSplits: 1).first.map(String.init) ?? entityId
    }

    private static func localizedDomainName(for domainName: String) -> String {
        guard let domain = Domain(rawValue: domainName) else { return domainName }
        return CoreStrings.getDomainLocalizedTitle(domain: domain)
    }

    private static func entityName(for entity: EntityRegistryListForDisplay.Entity) -> String {
        guard let name = entity.name, !name.isEmpty else { return entity.entityId }
        return name
    }

    private func openEntity(_ entityId: String, serverId: String) {
        guard let url = AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId) else {
            Current.Log.error("Failed to build entity URL for \(entityId) on server \(serverId)")
            return
        }
        handleIncoming(url: url)
    }

    private func handleIncoming(url: URL) {
        Current.sceneManager.appCoordinator.done { IncomingURLHandler(coordinator: $0).handle(url: url) }
    }
}

private struct AreasCommandServer: Identifiable {
    let id: String
    let name: String
    let floors: [AreasCommandFloor]
}

private struct AreasCommandFloor: Identifiable {
    let id: String
    let name: String
    let areas: [AreasCommandArea]
}

private struct AreasCommandFloorKey: Hashable {
    let id: String?
    let name: String
}

private struct AreasCommandArea: Identifiable {
    let id: String
    let name: String
    let floorId: String?
    let floorName: String?
    let devices: [AreasCommandDevice]
}

private struct AreasCommandDevice: Identifiable {
    let id: String
    let name: String
    let domains: [AreasCommandDomain]
}

private struct AreasCommandDomain: Identifiable {
    let id: String
    let name: String
    let entities: [AreasCommandEntity]
}

private struct AreasCommandEntity: Identifiable {
    var id: String { entityId }
    let entityId: String
    let name: String
}

private final class MainWindowGroupCommandsReloadObserver: ObservableObject {
    @Published var reloadID = UUID()

    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.observer = notificationCenter.addObserver(
            forName: .appDatabaseUpdaterDidFinishRoutine,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadID = UUID()
        }
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }
}
