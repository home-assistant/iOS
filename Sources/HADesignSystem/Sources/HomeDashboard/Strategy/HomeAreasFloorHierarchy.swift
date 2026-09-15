import Foundation

/// The home as floors with areas under them, plus the areas that belong to no floor. The port of the
/// frontend's `getAreasFloorHierarchy`.
///
/// Both lists keep the registry's order, which is the order the user dragged them into — so
/// reordering an area on one client moves it on every other.
public struct HomeAreasFloorHierarchy: Equatable, Sendable {
    public struct Floor: Equatable, Sendable {
        public let id: String
        public let areaIds: [String]

        public init(id: String, areaIds: [String]) {
            self.id = id
            self.areaIds = areaIds
        }
    }

    public let floors: [Floor]
    /// Areas on no floor at all.
    public let looseAreaIds: [String]

    public init(floors: [Floor], looseAreaIds: [String]) {
        self.floors = floors
        self.looseAreaIds = looseAreaIds
    }

    public static func build(floors: [HomeFloor], areas: [HomeArea]) -> HomeAreasFloorHierarchy {
        var areasByFloor: [String: [String]] = [:]
        var loose: [String] = []
        for area in areas {
            if let floorId = area.floorId {
                areasByFloor[floorId, default: []].append(area.id)
            } else {
                loose.append(area.id)
            }
        }
        return HomeAreasFloorHierarchy(
            floors: floors.map { Floor(id: $0.id, areaIds: areasByFloor[$0.id] ?? []) },
            looseAreaIds: loose
        )
    }

    /// Every area, floor by floor, loose areas last. The order the overview lays its cards out in and
    /// the order a drag has to rewrite.
    public var orderedAreaIds: [String] {
        floors.flatMap(\.areaIds) + looseAreaIds
    }

    /// How many headings the overview will draw: one per floor that has areas, plus one for the
    /// loose ones. It decides whether a single floor is named or just called "Areas".
    public var headingCount: Int {
        floors.count + (looseAreaIds.isEmpty ? 0 : 1)
    }
}
