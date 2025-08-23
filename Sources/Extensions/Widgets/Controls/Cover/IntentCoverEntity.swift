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
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 18.0, *)
struct IntentCoverAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentCoverEntity] {
        await getCoverEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentCoverEntity> {
        let CoveresPerServer = await getCoverEntities()

        return .init(sections: CoveresPerServer.map { (key: Server, value: [IntentCoverEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentCoverEntity> {
        let coversPerServer = await getCoverEntities()

        return .init(sections: coversPerServer.map { (key: Server, value: [IntentCoverEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getCoverEntities(matching string: String? = nil) async -> [(Server, [IntentCoverEntity])] {
        var coverEntities: [(Server, [IntentCoverEntity])] = []
        let entities = ControlEntityProvider(domains: [.cover]).getEntities(matching: string)

        for (server, values) in entities {
            coverEntities.append((server, values.map({ entity in
                IntentCoverEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.blindsVerticalOpen.rawValue
                )
            })))
        }

        return coverEntities
    }
}
