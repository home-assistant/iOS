import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 18.0, *)
struct IntentCoverEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cover")

    static let defaultQuery = IntentCoverAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    var entityId: String
    var serverId: String
    var areaName: String?
    var deviceName: String?
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    private var subtitle: String? {
        EntityContextSubtitle.make(
            areaName: areaName,
            deviceName: deviceName,
            entityName: displayString,
            entityId: entityId,
            domain: Domain(entityId: entityId)
        )
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        areaName: String? = nil,
        deviceName: String? = nil,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.areaName = areaName
        self.deviceName = deviceName
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 18.0, *)
struct IntentCoverAppEntityQuery: EntityQuery, EntityStringQuery {
    #if WIDGET_EXTENSION
    @IntentParameterDependency<ControlCoverConfiguration>(\.$server)
    var config
    #endif

    func entities(for identifiers: [String]) async throws -> [IntentCoverEntity] {
        await getCoverEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentCoverEntity> {
        await collection(for: getCoverEntities(matching: string))
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentCoverEntity> {
        await collection(for: getCoverEntities())
    }

    /// Scopes the list to the server picked in the configuration (flat list). When no server is
    /// selected (e.g. a widget configured before this option existed), falls back to grouping
    /// every server's entities into sections.
    private func collection(
        for entitiesPerServer: [(Server, [IntentCoverEntity])]
    ) -> IntentItemCollection<IntentCoverEntity> {
        #if WIDGET_EXTENSION
        if let server = config?.server {
            let items = entitiesPerServer.first { $0.0.identifier.rawValue == server.id }?.1 ?? []
            return .init(items: items)
        }
        #endif
        return .init(sections: entitiesPerServer.map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    private func getCoverEntities(matching string: String? = nil) async -> [(Server, [IntentCoverEntity])] {
        var coverEntities: [(Server, [IntentCoverEntity])] = []
        let entities = ControlEntityProvider(domains: [.cover]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            coverEntities.append((server, values.map({ entity in
                IntentCoverEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.blindsVerticalOpen.rawValue
                )
            })))
        }

        return coverEntities
    }
}
