import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

/// Any Home Assistant entity, unfiltered: what the Spotlight index publishes, what a widget or a
/// control is configured with, and what "show entity details" opens.
///
/// No command may take this type as a parameter. The system decides what a tapped Spotlight result
/// does from the intents that accept the indexed entity, so while the on/off and get-state commands
/// shared it, tapping a search result switched the entity off instead of opening it, with nothing in
/// the row to say so. Each spoken command carries its own narrower type — `ControllableEntityAppEntity`,
/// `ReadableEntityAppEntity`, `OpenableEntityAppEntity` — which is also what filters what Siri offers
/// for it. This one stays wide, because search has nothing to filter by.
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

    /// The domain this belongs to, which is what a picker draws its symbol from.
    ///
    /// Nothing here calls a service: this is what Spotlight publishes, what a widget is configured
    /// with and what "show entity details" opens. The spoken commands each carry their own entity
    /// type — `ControllableEntityAppEntity` and its siblings — which is what keeps a tapped search
    /// result opening the entity rather than switching it.
    var domain: Domain? {
        Domain(entityId: entityId)
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
}

@available(macOS 13.0, watchOS 9.4, *)
struct HAAppEntityAppIntentEntityQuery: EntityQuery, EntityStringQuery {
    /// Only ever single entities: an area is something to switch, which `ControllableEntityAppEntity`
    /// offers and reads back, not something to index, put in a widget or open the details of.
    func entities(for identifiers: [String]) async throws -> [HAAppEntityAppIntentEntity] {
        getEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
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
