import Foundation

/// The icon a floor shows when it has none of its own — the port of the frontend's
/// `floorDefaultIcon`, which picks a numbered-storey icon from the floor's level.
public enum HomeFloorIcon {
    /// The levels the frontend has a dedicated icon for; anything outside falls back to `mdi:home`.
    private static let numberedLevels = -1 ... 3

    public static func `default`(for floor: HomeFloor) -> String {
        guard let level = floor.level, numberedLevels.contains(level) else {
            return "mdi:home"
        }
        if level == -1 {
            return "mdi:home-floor-negative-1"
        }
        return "mdi:home-floor-\(level)"
    }

    /// The floor's own icon when it has one, the level-derived default otherwise.
    public static func resolved(for floor: HomeFloor) -> String {
        floor.icon ?? `default`(for: floor)
    }
}
