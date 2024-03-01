//
//  IntentActionAppEntity.swift
//  
//
//  Created by Bruno Pantaleão on 29/02/2024.
//

import Foundation
import AppIntents
import Shared

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct IntentActionAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")

    struct IntentActionAppEntityQuery: EntityQuery, EntityStringQuery {
        func entities(for identifiers: [IntentActionAppEntity.ID]) async throws -> [IntentActionAppEntity] {
            return getActionEntities().filter { identifiers.contains($0.id) }
        }

        func entities(matching string: String) async throws -> [IntentActionAppEntity] {
            return getActionEntities().filter { $0.displayString.contains(string) }
        }

        func suggestedEntities() async throws -> [IntentActionAppEntity] {
            return getActionEntities()
        }

        private func getActionEntities() -> [IntentActionAppEntity] {
            let actions = Current.realm().objects(Action.self).sorted(byKeyPath: #keyPath(Action.Position))
            return Array(actions.map { IntentActionAppEntity(id: $0.ID, displayString: $0.Name) })
        }
    }
    static var defaultQuery = IntentActionAppEntityQuery()

    var id: String // if your identifier is not a String, conform the entity to EntityIdentifierConvertible.
    var displayString: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(id: String, displayString: String) {
        self.id = id
        self.displayString = displayString
    }
}

