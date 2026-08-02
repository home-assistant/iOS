import Foundation

/// How the watch home screen presents the automatic area rows, so users can browse and control
/// entities by area without configuring items first.
public enum WatchHomeAreasMode: Equatable {
    /// No area rows: the user hid them, or no area contains a watch-compatible entity.
    case hidden
    /// Few enough areas on a single server to list each one directly on the home screen.
    case inline([AppArea])
    /// A single "Areas" row that drills into the server picker (multiple servers) or the area list.
    case grouped(serverIds: [String])

    /// Above this many areas the home screen collapses them into the single grouped row.
    public static var maxInlineAreas: Int { 5 }

    /// Decides the presentation from the mirrored data. Areas without any watch-compatible entity
    /// are dropped — their screen would always be empty.
    public static func compute(
        areas: [AppArea],
        watchEntityIdsByServer: [String: Set<String>],
        hideAreas: Bool
    ) -> WatchHomeAreasMode {
        guard !hideAreas else { return .hidden }
        let populatedAreas = areas.filter { area in
            guard let entityIds = watchEntityIdsByServer[area.serverId] else { return false }
            return !area.entities.isDisjoint(with: entityIds)
        }
        guard !populatedAreas.isEmpty else { return .hidden }
        // Ordered by first appearance so the picker follows the areas' display order.
        var serverIds: [String] = []
        for area in populatedAreas where !serverIds.contains(area.serverId) {
            serverIds.append(area.serverId)
        }
        if serverIds.count == 1, populatedAreas.count <= maxInlineAreas {
            return .inline(populatedAreas)
        }
        return .grouped(serverIds: serverIds)
    }
}
