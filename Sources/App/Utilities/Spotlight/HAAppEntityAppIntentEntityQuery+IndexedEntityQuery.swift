import AppIntents
import CoreSpotlight
import Foundation
import Shared

/// Lets the system ask for a Spotlight refresh instead of waiting for the app's own pass, which only
/// runs when the database changes or the app comes to the foreground.
@available(iOS 27.0, *)
extension HAAppEntityAppIntentEntityQuery: IndexedEntityQuery {
    func reindexEntities(
        for identifiers: [String],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await SpotlightEntityIndexer.shared.reindex(entityIds: identifiers)
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        await SpotlightEntityIndexer.shared.reindexEverything()
    }
}
