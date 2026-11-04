import AppIntents
import Foundation
import Shared

/// Offers only the destinations that could actually take the entity: the ones this device has, and
/// the ones that can show what is being added.
///
/// The same two questions `AddEntityToAppIntent` asks before it writes anything, asked early enough
/// that nobody picks an answer that was never going to work — a Mac has no CarPlay quick access and
/// no watch paired the way a phone does, an iPhone has no Mac toolbar, and neither the watch nor
/// CarPlay can draw a domain it has no row for. `perform` keeps its own guards: a shortcut saved on
/// one device runs on another, and a spoken phrase names a destination without consulting a list.
@available(iOS 17.0, macOS 14.0, *)
struct EntityAddToDestinationOptionsProvider: DynamicOptionsProvider {
    /// The entity chosen for this same intent, which is what says whether a destination can show it.
    /// Nil until one is picked — asked in that order, every destination this device has is offered.
    @IntentParameterDependency<AddEntityToAppIntent>(\.$entity)
    var addEntityTo

    func results() async throws -> [EntityAddToDestinationAppEnum] {
        let entityId = addEntityTo?.entity.entityId
        // `isAvailable` reads `UIDevice`, so the filtering happens where that is safe to touch.
        return await MainActor.run { Self.destinations(showing: entityId) }
    }

    /// Nil entity means nothing has been ruled out yet, so every destination this device has stands.
    @MainActor
    static func destinations(showing entityId: String?) -> [EntityAddToDestinationAppEnum] {
        EntityAddToDestinationAppEnum.allCases.filter { destination in
            guard destination.isAvailable else { return false }
            guard let entityId else { return true }
            return destination.supports(entityId: entityId)
        }
    }
}
