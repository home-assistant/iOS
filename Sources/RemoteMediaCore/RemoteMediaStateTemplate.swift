import Foundation

/// The `render_template` query the extension uses to read one player's state back.
///
/// Deliberately narrow: it names the followed entity and returns only the attributes RemoteMedia
/// renders. Asking for the whole state machine would cost the extension memory it does not have,
/// and this process has no business seeing the rest of the user's home.
///
/// **Transitional.** A `nowplaying` APNs update is the authoritative way this card learns about a
/// change, and it works while nothing of ours is running — which read-back never can, because it
/// only happens after a command the user pressed. This exists because the Home Assistant server
/// cannot send those pushes yet. Once it can, the read-back ladder becomes at most one delayed
/// fallback for a push that never arrived; see `RemoteMediaReconciler`.
public enum RemoteMediaStateTemplate {
    /// The key the rendered result comes back under in the webhook response.
    public static let resultKey = "media"

    /// `media_position_updated_at` is a datetime in templates, so it goes through `isoformat()`;
    /// everything else survives `to_json` as it is.
    public static func template(entityId: String) -> String {
        """
        {% set e = states['\(entityId)'] %}\
        {% if e is none %}{{ {'missing': true} | to_json }}{% else %}{{ {\
        'entity_id': '\(entityId)',\
        'state': e.state,\
        'media_content_id': e.attributes.get('media_content_id'),\
        'media_title': e.attributes.get('media_title'),\
        'media_artist': e.attributes.get('media_artist'),\
        'media_album_name': e.attributes.get('media_album_name'),\
        'media_duration': e.attributes.get('media_duration'),\
        'media_position': e.attributes.get('media_position'),\
        'media_position_updated_at': (e.attributes.get('media_position_updated_at').isoformat() \
        if e.attributes.get('media_position_updated_at') else None),\
        'entity_picture': e.attributes.get('entity_picture'),\
        'volume_level': e.attributes.get('volume_level'),\
        'is_volume_muted': e.attributes.get('is_volume_muted'),\
        'friendly_name': e.attributes.get('friendly_name'),\
        'device_class': e.attributes.get('device_class'),\
        'supported_features': e.attributes.get('supported_features')\
        } | to_json }}{% endif %}
        """
    }

    /// Maps a rendered response onto the same DTO the host app's HAKit path produces, so the
    /// foreground and background views of a player cannot disagree.
    public static func readback(from rendered: Any, serverId: String) -> RemoteMediaStateReadback {
        let object: [String: Any]?
        switch rendered {
        case let dictionary as [String: Any]:
            object = dictionary
        case let text as String:
            object = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        default:
            object = nil
        }
        guard let object else { return .unreadable }
        if object["missing"] as? Bool == true { return .missing }
        guard let entityId = object["entity_id"] as? String,
              let state = object["state"] as? String,
              let entityState = RemoteMediaSnapshotMapper.map(
                  entityId: entityId,
                  state: state,
                  attributes: object,
                  serverId: serverId
              ) else { return .unreadable }
        return .entity(entityState)
    }
}
