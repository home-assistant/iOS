import AppIntents
import Foundation
import Shared

/// Turns the entity the frontend's more-info dialog is showing into the `EntityIdentifier`s the system
/// attaches to it, which is what lets Siri resolve "turn this off", "open this" or "add this to
/// CarPlay" against whatever the user is looking at rather than asking them to name it again.
///
/// A command binds to the identifier whose type its own parameter takes, and an activity carries one
/// identifier, so the fewer types an entity is modelled by the better this works. There are two:
/// `HAAppEntityAppIntentEntity` for everything, and `OpenableEntityAppEntity` for covers, which stay
/// separate because a phrase's candidate list comes from its parameter type's own query and "open"
/// should offer covers alone.
@available(iOS 18.2, *)
enum OnscreenEntityIdentifier {
    /// Every identifier the entity answers to, most specific command first.
    ///
    /// A cover leads with the type that opens and closes it, since the one identifier an activity can
    /// carry is the first, and "open this" is how a cover is asked for.
    static func makeAll(entityId: String, serverId: String) async -> [EntityIdentifier] {
        // Hiding a server from Siri hides what it is showing too, for the same reason the page does.
        guard SiriServerExposure.isExposed(serverId: serverId), let domain = Domain(entityId: entityId) else {
            return []
        }
        let id = ServerEntity.uniqueId(serverId: serverId, entityId: entityId)
        var identifiers: [EntityIdentifier] = []

        if Domain.voiceOpenable.contains(domain) {
            await identifiers.appendIfResolved(by: OpenableEntityAppEntityQuery(), id: id)
        }
        await identifiers.appendIfResolved(by: HAAppEntityAppIntentEntityQuery(), id: id)

        return identifiers
    }

    /// The single identifier a user activity can carry, for the releases with nowhere to put the rest.
    static func make(entityId: String, serverId: String) async -> EntityIdentifier? {
        await makeAll(entityId: entityId, serverId: serverId).first
    }
}

private extension [EntityIdentifier] {
    /// Appends the identifier only when the very query the matching intent's parameter uses can turn it
    /// back into an entity, so nothing is published that the system would then fail to look up: an
    /// entity a query leaves out — a cover in no room, for the cover type — is simply not named by it.
    mutating func appendIfResolved<Query: EntityQuery>(by query: Query, id: Query.Entity.ID) async {
        guard let entity = try? await query.entities(for: [id]).first else { return }
        append(EntityIdentifier(for: entity))
    }
}
