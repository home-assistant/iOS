import AppIntents
import CoreSpotlight
import Foundation
import Shared

/// A Home Assistant todo list in the shape Apple Intelligence understands.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.list)
struct ReminderListSchemaEntity: IndexedEntity {
    static let defaultQuery = ReminderListSchemaEntityQuery()

    var id: String
    var name: String
    var type: ReminderListTypeSchemaEnum

    /// The entity id the todo services address, kept off the schema shape.
    var entityId: String
    var serverId: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(name)", image: .init(systemName: "checklist"))
    }

    init(entity: HAAppEntity) {
        // Plain properties first: the schema's own are wrapped, and a wrapper setter goes through
        // `self`, which Swift requires to be fully initialized.
        self.id = entity.id
        self.entityId = entity.entityId
        self.serverId = entity.serverId
        self.name = entity.name
        self.type = .standard
    }

    /// An empty list, for the transient section entity that must carry one to satisfy the schema.
    init() {
        self.id = ""
        self.entityId = ""
        self.serverId = ""
        self.name = ""
        self.type = .standard
    }
}
