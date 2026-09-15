import Foundation

/// Taking an entity id apart, the way the frontend's `compute_domain` and `compute_object_id` do.
public enum HomeEntityID {
    /// `"light"` for `"light.kitchen"`; the whole string when there is no dot.
    public static func domain(of entityId: String) -> String {
        guard let separator = entityId.firstIndex(of: ".") else {
            return entityId
        }
        return String(entityId[entityId.startIndex ..< separator])
    }

    /// `"kitchen"` for `"light.kitchen"`; an empty string when there is no dot.
    public static func objectId(of entityId: String) -> String {
        guard let separator = entityId.firstIndex(of: ".") else {
            return ""
        }
        return String(entityId[entityId.index(after: separator)...])
    }
}
