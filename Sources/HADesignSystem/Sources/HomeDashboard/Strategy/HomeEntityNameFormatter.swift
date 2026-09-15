import Foundation

/// Naming an entity the way the dashboard does: the state's own name, and the area's name taken off
/// the front of it so a room full of "Kitchen ceiling", "Kitchen counter" reads as "Ceiling",
/// "Counter". The port of `computeStateName` and `stripPrefixFromEntityName`.
public enum HomeEntityNameFormatter {
    /// The separators a prefix can be followed by. Anything else is not a prefix, it is the name.
    private static let separators = [" ", ": ", " - "]

    /// The entity's name: its `friendly_name`, or its object id with the underscores opened up.
    public static func name(of state: HomeEntityState) -> String {
        if let friendlyName = state.attributes.friendlyName {
            return friendlyName
        }
        return HomeEntityID.objectId(of: state.id).replacingOccurrences(of: "_", with: " ")
    }

    /// The name with `prefix` stripped off the front, or `nil` when it does not start with it —
    /// `nil` meaning "no override", which is how the frontend signals the same thing.
    public static func strippingPrefix(_ prefix: String, from name: String) -> String? {
        guard !prefix.isEmpty else {
            return nil
        }
        let loweredName = name.lowercased()
        let loweredPrefix = prefix.lowercased()
        for separator in separators {
            let candidate = loweredPrefix + separator
            guard loweredName.hasPrefix(candidate) else {
                continue
            }
            let stripped = String(name.dropFirst(candidate.count))
            guard !stripped.isEmpty else {
                continue
            }
            return capitalizingFirstWordIfNeeded(stripped)
        }
        return nil
    }

    /// A brand name keeps its own capitals; anything else gets a capital letter where the area's name
    /// used to be.
    private static func capitalizingFirstWordIfNeeded(_ name: String) -> String {
        let firstWord = name.prefix { $0 != " " }
        if firstWord.lowercased() != firstWord {
            return name
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
