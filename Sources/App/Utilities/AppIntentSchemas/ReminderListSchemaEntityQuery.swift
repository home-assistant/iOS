import AppIntents
import Foundation
import Shared

@available(iOS 27.0, *)
struct ReminderListSchemaEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ReminderListSchemaEntity] {
        let wanted = Set(identifiers)
        return lists().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ReminderListSchemaEntity] {
        lists().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [ReminderListSchemaEntity] {
        lists()
    }

    func defaultResult() async -> ReminderListSchemaEntity? {
        defaultList()
    }

    func lists() -> [ReminderListSchemaEntity] {
        let hidden = SiriEntityExposure.hiddenEntityIds(domain: Domain.todo.rawValue)
        return ControlEntityProvider(domains: [.todo]).getEntitiesExposedToSiri()
            .flatMap(\.1)
            .filter { !hidden.contains($0.id) }
            .map(ReminderListSchemaEntity.init(entity:))
    }

    func defaultList() -> ReminderListSchemaEntity? {
        let defaults = SiriEntityExposure.defaultEntityIds(domain: Domain.todo.rawValue)
        guard !defaults.isEmpty else { return nil }
        return lists().first { defaults.contains($0.id) }
    }
}
