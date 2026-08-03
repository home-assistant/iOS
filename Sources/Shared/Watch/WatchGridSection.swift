import Foundation

/// One stretch of the watch home screen's grid layout, in configured order.
///
/// A rectangular complication is a wide, multi-line layout — it has nothing to show inside a 60-point
/// square tile — so in grid layout it takes a full-width row of its own while the items around it stay
/// tiled. Splitting the list into consecutive runs keeps the user's ordering intact, which pulling all
/// complications to the end would not.
public enum WatchGridSection: Identifiable, Equatable {
    /// Consecutive items that render as square tiles inside one grid.
    case tiles([MagicItem])
    /// A single complication, rendered full width between the grids around it.
    case complication(MagicItem)

    public var id: String {
        switch self {
        case let .tiles(items):
            // Runs are consecutive and items are unique, so the first one identifies the run.
            return "tiles-\(items.first?.serverUniqueId ?? "")"
        case let .complication(item):
            return "complication-\(item.serverUniqueId)"
        }
    }

    public static func sections(for items: [MagicItem]) -> [WatchGridSection] {
        var sections: [WatchGridSection] = []
        var pendingTiles: [MagicItem] = []

        func flushTiles() {
            guard !pendingTiles.isEmpty else { return }
            sections.append(.tiles(pendingTiles))
            pendingTiles = []
        }

        for item in items {
            if item.type == .complication {
                flushTiles()
                sections.append(.complication(item))
            } else {
                pendingTiles.append(item)
            }
        }
        flushTiles()
        return sections
    }
}
