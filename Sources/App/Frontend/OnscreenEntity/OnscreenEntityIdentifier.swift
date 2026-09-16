import AppIntents
import Foundation
import Shared

/// Turns the entity the frontend's more-info dialog is showing into the `EntityIdentifier`s the system
/// attaches to it, which is what lets Siri resolve "turn this off", "open this" or "add this to
/// CarPlay" against whatever the user is looking at rather than asking them to name it again.
///
/// A command binds to the identifier whose type its own parameter takes, and an activity carries one
/// identifier, so the order they come in matters. Every command narrows its candidates with a type of
/// its own — `ControllableEntityAppEntity` for on and off, `ReadableEntityAppEntity` for the question,
/// `OpenableEntityAppEntity` for covers, `DimmableLightAppEntity`, `ThermostatAppEntity` and
/// `LockAppEntity` for dimming, setting and locking — while `HAAppEntityAppIntentEntity` names every
/// entity and is what "add this to CarPlay" and "show this" take.
@available(iOS 18.2, *)
enum OnscreenEntityIdentifier {
    /// Every identifier the entity answers to, the one an activity should carry first.
    ///
    /// The type whose command acts on the entity leads, since the one identifier an activity can carry
    /// is the first (iOS 18.2 and 18.3): "open this" for a cover, "turn this off" for anything else
    /// that switches. An entity no command acts on leads with the question's type instead, which is
    /// the only thing to say to a sensor. The shared type follows, so the add-to commands keep working,
    /// then the question's type where a command already led, then the type a light's, thermostat's or
    /// lock's own command takes, for the releases that read them all.
    static func makeAll(entityId: String, serverId: String) async -> [EntityIdentifier] {
        // Hiding a server from Siri hides what it is showing too, for the same reason the page does.
        guard SiriServerExposure.isExposed(serverId: serverId), let domain = Domain(entityId: entityId) else {
            return []
        }
        let id = ServerEntity.uniqueId(serverId: serverId, entityId: entityId)
        let switchesItself = Domain.voiceOpenable.contains(domain) || Domain.voiceSwitchOffered.contains(domain)
        let isReadable = Domain.voiceReadable.contains(domain)
        var identifiers: [EntityIdentifier] = []

        // Each command's own type is published only for the domains that command offers: resolution is
        // deliberately wider than that, so asking the query alone would name a sensor as something to
        // switch off.
        if Domain.voiceOpenable.contains(domain) {
            await identifiers.appendIfResolved(by: OpenableEntityAppEntityQuery(), id: id)
        } else if Domain.voiceSwitchOffered.contains(domain) {
            await identifiers.appendIfResolved(by: ControllableEntityAppEntityQuery(), id: id)
        } else if isReadable {
            await identifiers.appendIfResolved(by: ReadableEntityAppEntityQuery(), id: id)
        }
        await identifiers.appendIfResolved(by: HAAppEntityAppIntentEntityQuery(), id: id)
        if switchesItself, isReadable {
            await identifiers.appendIfResolved(by: ReadableEntityAppEntityQuery(), id: id)
        }
        switch domain {
        case .light:
            await identifiers.appendIfResolved(by: DimmableLightAppEntityQuery(), id: id)
        case .climate:
            await identifiers.appendIfResolved(by: ThermostatAppEntityQuery(), id: id)
        case .lock:
            await identifiers.appendIfResolved(by: LockAppEntityQuery(), id: id)
        default:
            break
        }

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
