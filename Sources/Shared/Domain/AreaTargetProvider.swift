import Foundation

/// Builds the area targets a spoken command offers alongside its individual entities.
///
/// Kept apart from the queries that use it because both the on/off and the open/close command need
/// the same list, differing only in which domains they can act on.
public enum AreaTargetProvider {
    /// The areas of `server` holding something in `domains`, as targets a command can act on.
    ///
    /// - Parameter string: what the user typed or said, matched against the area's name, its
    ///   aliases and the target's full name. `nil` offers everything, for a picker.
    ///
    /// The entities are read through the same provider the picker uses, so a target inherits every
    /// filter already applied to them: a server kept out of Siri contributes no areas, and neither
    /// do hidden, configuration or diagnostic entities.
    public static func targets(
        for server: Server,
        domains: [Domain],
        matching string: String? = nil
    ) -> [AreaTarget] {
        let serverId = server.identifier.rawValue
        // Deliberately unfiltered by name: "living room" names an area, and matching it against
        // entity names first would leave nothing to build an area out of.
        let entities = ControlEntityProvider(domains: domains).getEntitiesExposedToSiri()
            .first { $0.0.identifier == server.identifier }?
            .1 ?? []
        guard !entities.isEmpty, let areas = try? AppArea.fetchAreas(for: serverId) else {
            return []
        }

        let targets = entities.userFacingInAreas(serverId: serverId)
            .areaTargets(in: areas, domains: domains)
        guard let string, !string.isEmpty else { return targets }
        return targets.filter { $0.matches(string) }
    }
}
