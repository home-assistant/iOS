import Foundation

/// Whether an entity id is one this feature may follow.
///
/// A followed id reaches two very different places: a JSON `service_data` value, where anything is
/// safe, and `RemoteMediaStateTemplate`, where it is interpolated into a Jinja template that Home
/// Assistant executes. The template is the reason this is a character-set check and not just a
/// domain prefix: an id carrying an apostrophe closes the quoted literal it sits in, and everything
/// after it is template source the server will run. Ids arrive from the frontend's "Add to" message
/// and are persisted, so the check belongs at the boundary rather than in the template's string
/// interpolation, where it could only be a second guess at what is already stored.
///
/// The accepted set is the one Home Assistant itself slugifies to — lowercase letters, digits and
/// underscores. `homeassistant.core.valid_entity_id` additionally rejects leading, trailing and
/// doubled underscores; those are deliberately not mirrored here, because refusing to follow a
/// player the server considers valid would be a worse failure than accepting an odd-looking id
/// that cannot escape anything.
public enum RemoteMediaEntityId {
    /// The only domain this feature works with.
    public static let domainPrefix = "media_player."

    public static func isValid(_ entityId: String) -> Bool {
        guard entityId.hasPrefix(domainPrefix) else { return false }
        let objectId = entityId.dropFirst(domainPrefix.count)
        guard !objectId.isEmpty else { return false }
        return objectId.allSatisfy { character in
            character.isASCII && (character.isLowercase || character.isNumber || character == "_")
        }
    }
}
