import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(macOS 13.0, watchOS 9.4, *)
struct HAAppEntityAppIntentEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Entity")

    static let defaultQuery = HAAppEntityAppIntentEntityQuery()

    var id: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    var serverId: String
    @Property(title: .init("app_intents.entity.property.server", defaultValue: "Server"))
    var serverName: String
    @Property(title: .init("app_intents.entity.property.area", defaultValue: "Area"))
    var areaName: String?
    @Property(title: .init("app_intents.entity.property.device", defaultValue: "Device"))
    var deviceName: String?
    @Property(title: .init("app_intents.entity.property.floor", defaultValue: "Floor"))
    var floorName: String?
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
    var displayString: String
    var iconName: String
    /// Whether the server name leads the context line. Only the Spotlight index sets this, and only
    /// when more than one server is configured: its results stand alone, while every picker already
    /// groups entities under a per-server section.
    var includesServerContext: Bool
    /// Set when this stands for a whole area's worth of one domain rather than a single entity, in
    /// which case `entityId` is empty and a command targets the area instead.
    ///
    /// Only the on/off command's own option list offers these — an area is something to switch, not
    /// something to index, put in a widget or add to the watch — but they resolve through the shared
    /// query like any other id, so a shortcut saved against a room keeps working.
    var areaTarget: AreaTarget?

    /// The domain a command resolves its service from, e.g. `cover` opens rather than turns on.
    var domain: Domain? {
        areaTarget?.domain ?? Domain(entityId: entityId)
    }

    /// What a service call should be addressed to: one entity, or the whole area this stands for.
    ///
    /// Home Assistant scopes an area target by the calling service's domain, so `light.turn_on`
    /// against an area reaches its lights and nothing else in the room.
    var serviceTarget: [String: Any] {
        if let areaTarget {
            return ["area_id": areaTarget.areaId]
        }
        return ["entity_id": entityId]
    }

    /// The icon is the domain's SF Symbol, not the entity's own Material Design glyph.
    ///
    /// Drawing the glyph here meant rendering an image per row as the list scrolled, which made the
    /// Shortcuts app stutter. A symbol name costs nothing to pass and the system draws it. Spotlight
    /// results still carry the real glyph, where it is rendered once per index pass.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) },
            image: .init(systemName: domain?.sfSymbolName ?? Self.fallbackSymbolName)
        )
    }

    /// A domain the app does not model still gets a row, and an on/off glyph is the least wrong
    /// thing to show for one.
    static let fallbackSymbolName = SFSymbol.powerCircle.rawValue

    /// The `Server • Floor • Area • Device` line shown under the entity name.
    var subtitle: String? {
        // An area row already names its area in the title, so it takes the server as its second line
        // (and nothing at all when there is only one) rather than repeating itself.
        guard areaTarget == nil else {
            return Current.servers.all.count > 1 ? serverName : nil
        }
        guard includesServerContext else {
            return contextSubtitle
        }
        return EntityContextSubtitle.make(
            serverName: serverName,
            floorName: floorName,
            areaName: areaName,
            deviceName: deviceName,
            entityName: displayString,
            entityId: entityId,
            domain: domain
        )
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        serverName: String,
        areaName: String? = nil,
        deviceName: String? = nil,
        floorName: String? = nil,
        displayString: String,
        iconName: String,
        includesServerContext: Bool = false
    ) {
        self.id = id
        self.serverId = serverId
        self.iconName = iconName
        self.includesServerContext = includesServerContext
        self.entityId = entityId
        self.serverName = serverName
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.displayString = displayString
    }

    /// Every area this server offers as a target, built the one way so the list that offers them and
    /// the query that reads them back can never disagree on an id.
    ///
    /// Resolution passes every domain an area can be targeted for; an option list passes the narrower
    /// set it means to offer, and gets a subset of the same ids.
    static func areaTargets(
        for server: Server,
        matching string: String?,
        domains: [Domain] = Domain.voiceControllable
    ) -> [HAAppEntityAppIntentEntity] {
        AreaTargetProvider.targets(for: server, domains: domains, matching: string)
            .map {
                HAAppEntityAppIntentEntity(
                    areaTarget: $0,
                    serverId: server.identifier.rawValue,
                    serverName: server.info.name
                )
            }
    }

    /// A whole area of one domain, standing in for every entity of that kind in the room.
    init(areaTarget: AreaTarget, serverId: String, serverName: String) {
        self.id = areaTarget.id(serverId: serverId)
        self.serverId = serverId
        self.iconName = areaTarget.iconName
        self.includesServerContext = false
        self.areaTarget = areaTarget
        self.entityId = ""
        self.serverName = serverName
        self.areaName = areaTarget.areaName
        self.deviceName = nil
        self.floorName = nil
        self.displayString = areaTarget.displayName
    }
}

@available(macOS 13.0, watchOS 9.4, *)
struct HAAppEntityAppIntentEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HAAppEntityAppIntentEntity] {
        let byServer = getEntities()
        let resolved = byServer.flatMap(\.1).filter { identifiers.contains($0.id) }
        // An area id resolves through the same builder the on/off list offers, so a shortcut saved
        // against a room keeps working whether it stored one entity or the whole room. Only that list
        // ever produces them, but resolution is shared, so it has to know how to read one back.
        //
        // Building them reads the areas back out of the database, and every other caller — a widget,
        // a Spotlight result — only ever asks about entities, so nothing is built until an id is left
        // over that could only be a room.
        guard !Set(identifiers).subtracting(resolved.map(\.id)).isEmpty else { return resolved }
        let areas = byServer.flatMap { server, _ in
            HAAppEntityAppIntentEntity.areaTargets(for: server, matching: nil)
        }
        .filter { identifiers.contains($0.id) }
        return resolved + areas
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: getEntities(matching: string).map { (key: Server, value: [HAAppEntityAppIntentEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: getEntities().map { (key: Server, value: [HAAppEntityAppIntentEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getEntities(matching string: String? = nil) -> [(Server, [HAAppEntityAppIntentEntity])] {
        var allEntities: [(Server, [HAAppEntityAppIntentEntity])] = []
        let entities = ControlEntityProvider(domains: []).getEntitiesExposedToSiri(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)

            allEntities.append((server, values.map({ entity in
                HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name ?? "",
                    deviceName: deviceMap[entity.entityId]?.name ?? "",
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.applescriptFill.rawValue
                )
            })))
        }

        return allEntities
    }
}

@available(macOS 13.0, watchOS 9.4, *)
func makeHAEntityIntentItemCollection(
    entities: [(Server, [HAAppEntity])],
    defaultIconName: String
) -> IntentItemCollection<HAAppEntityAppIntentEntity> {
    .init(sections: entities.map { (server: Server, values: [HAAppEntity]) in
        let areasMap = values.areasMap(for: server.identifier.rawValue)
        let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
        return .init(
            .init(stringLiteral: server.info.name),
            items: values.map { entity in
                HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? defaultIconName
                )
            }
        )
    })
}
