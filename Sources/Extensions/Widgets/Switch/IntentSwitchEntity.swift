// import AppIntents
// import Foundation
// import GRDB
// import Shared
//
// @available(iOS 18.0, *)
// struct IntentSwitchEntity: AppEntity {
//    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Switch")
//
//    static let defaultQuery = IntentSwitchAppEntityQuery()
//
//    // UniqueID: serverId-entityId
//    var id: String
//    var entityId: String
//    var serverId: String
//    var displayString: String
//    var iconName: String
//    var displayRepresentation: DisplayRepresentation {
//        DisplayRepresentation(title: "\(displayString)")
//    }
//
//    init(
//        id: String,
//        entityId: String,
//        serverId: String,
//        displayString: String,
//        iconName: String
//    ) {
//        self.id = id
//        self.entityId = entityId
//        self.serverId = serverId
//        self.displayString = displayString
//        self.iconName = iconName
//    }
// }
//
// @available(iOS 18.0, *)
// struct IntentSwitchAppEntityQuery: EntityQuery, EntityStringQuery {
//    func entities(for identifiers: [String]) async throws -> [IntentSwitchEntity] {
//        await getSwitchEntities().flatMap(\.value).filter { identifiers.contains($0.id) }
//    }
//
//    func entities(matching string: String) async throws -> IntentItemCollection<IntentSwitchEntity> {
//        let switchesPerServer = await getSwitchEntities()
//
//        return .init(sections: switchesPerServer.map { (key: Server, value: [IntentSwitchEntity]) in
//            .init(
//                .init(stringLiteral: key.info.name),
//                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
//            )
//        })
//    }
//
//    func suggestedEntities() async throws -> IntentItemCollection<IntentSwitchEntity> {
//        let switchesPerServer = await getSwitchEntities()
//
//        return .init(sections: switchesPerServer.map { (key: Server, value: [IntentSwitchEntity]) in
//            .init(.init(stringLiteral: key.info.name), items: value)
//        })
//    }
//
//    private func getSwitchEntities(matching string: String? = nil) async -> [Server: [IntentSwitchEntity]] {
//        await withCheckedContinuation { continuation in
//            var entities: [Server: [IntentSwitchEntity]] = [:]
//            var serverCheckedCount = 0
//            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
//                do {
//                    let switches: [HAAppEntity] = try Current.database().read { db in
//                        try HAAppEntity
//                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
//                            .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.switch.rawValue)
//                            .fetchAll(db)
//                    }
//                    entities[server] = switches.map({ entity in
//                        .init(
//                            id: entity.id,
//                            entityId: entity.entityId,
//                            serverId: server.identifier.rawValue,
//                            displayString: entity.name,
//                            iconName: entity.icon ?? ""
//                        )
//                    })
//                } catch {
//                    Current.Log.error("Failed to load lights from database: \(error.localizedDescription)")
//                }
//                serverCheckedCount += 1
//                if serverCheckedCount == Current.servers.all.count {
//                    continuation.resume(returning: entities)
//                }
//            }
//        }
//    }
// }
