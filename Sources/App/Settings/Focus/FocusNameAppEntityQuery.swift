import AppIntents
import Foundation
import Shared

struct FocusNameAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [FocusNameAppEntity] {
        identifiers.compactMap { identifier in
            FocusName.get(id: identifier).map(FocusNameAppEntity.init(focusName:))
        }
    }

    func entities(matching string: String) async throws -> [FocusNameAppEntity] {
        FocusName.all()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(FocusNameAppEntity.init(focusName:))
    }

    func suggestedEntities() async throws -> [FocusNameAppEntity] {
        FocusName.all().map(FocusNameAppEntity.init(focusName:))
    }
}
