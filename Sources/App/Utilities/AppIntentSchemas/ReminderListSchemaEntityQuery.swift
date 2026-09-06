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

    private func lists() -> [ReminderListSchemaEntity] {
        ControlEntityProvider(domains: [.todo]).getEntities()
            .flatMap(\.1)
            .map(ReminderListSchemaEntity.init(entity:))
    }

    /// The list a new reminder lands on when none was named: the first the provider reports, which
    /// follows the app's own server and entity ordering.
    func firstList() -> ReminderListSchemaEntity? {
        lists().first
    }
}
