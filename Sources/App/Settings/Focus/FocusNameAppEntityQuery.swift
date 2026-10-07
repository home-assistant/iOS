import AppIntents
import Foundation
import Shared

/// Answers iOS about the Focus names when it draws the filter's configuration, and when it hands
/// the stored choice back to the filter as it runs.
///
/// Every read here throws rather than falling back to "no such name". iOS reads a missing entity
/// as one the user deleted and runs the filter with no name at all, which `perform()` can only
/// treat as a Focus deactivating — so a database it merely failed to open would blank the Focus
/// sensors for a Focus that is starting.
struct FocusNameAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [FocusNameAppEntity] {
        try identifiers.compactMap { identifier in
            try FocusName.fetch(id: identifier).map(FocusNameAppEntity.init(focusName:))
        }
    }

    func entities(matching string: String) async throws -> [FocusNameAppEntity] {
        try FocusName.fetchAll()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(FocusNameAppEntity.init(focusName:))
    }

    func suggestedEntities() async throws -> [FocusNameAppEntity] {
        try FocusName.fetchAll().map(FocusNameAppEntity.init(focusName:))
    }
}
