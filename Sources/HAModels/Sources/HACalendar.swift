import Foundation
import GRDB

/// A Home Assistant calendar entity, denormalized for rendering and for exposing to the system.
///
/// Mirrors what the frontend calls a `Calendar` (`src/data/calendar.ts`): every entity in the
/// `calendar` domain that currently has a state, is not `unavailable`, and is not hidden in the
/// entity registry. The rows are rebuilt by the app database update routine from the same `/states`
/// payload the entity cache is built from, so no extra round-trip is needed.
public struct HACalendar: Codable, Identifiable, FetchableRecord, PersistableRecord, Equatable {
    public static let databaseTableName = GRDBDatabaseTable.HACalendar.rawValue

    /// serverId-entityId
    public let id: String
    public let serverId: String
    public let entityId: String
    /// Resolved display name, matching `HAAppEntity.name` resolution.
    public let name: String
    /// Hex color (`#rrggbb`) used to tint the calendar, matching the frontend's palette.
    public let backgroundColor: String
    /// The `supported_features` bitmask from the entity's state attributes; see `Feature`.
    public let supportedFeatures: Int
    /// Position of the calendar in the entity-id-sorted list, which is also what picks its color.
    public let sortOrder: Int

    public init(
        id: String,
        serverId: String,
        entityId: String,
        name: String,
        backgroundColor: String,
        supportedFeatures: Int,
        sortOrder: Int
    ) {
        self.id = id
        self.serverId = serverId
        self.entityId = entityId
        self.name = name
        self.backgroundColor = backgroundColor
        self.supportedFeatures = supportedFeatures
        self.sortOrder = sortOrder
    }

    /// `supported_features` bits from Home Assistant's `CalendarEntityFeature`.
    public enum Feature: Int {
        case createEvent = 1
        case deleteEvent = 2
        case updateEvent = 4
    }

    public func supports(_ feature: Feature) -> Bool {
        supportedFeatures & feature.rawValue != 0
    }

    /// The frontend's `--color-1` … `--color-54` palette, used for calendars, graphs and maps.
    /// A calendar with no registry color override gets `defaultColors[index % count]`, exactly like
    /// `getColorByIndex` does in `src/common/color/colors.ts`.
    public static let defaultColors: [String] = [
        "#4269d0", "#f4bd4a", "#ff725c", "#6cc5b0", "#a463f2", "#ff8ab7",
        "#9c6b4e", "#97bbf5", "#01ab63", "#094bad", "#c99000", "#d84f3e",
        "#49a28f", "#048732", "#d96895", "#8043ce", "#7599d1", "#7a4c31",
        "#6989f4", "#ffd444", "#ff957c", "#8fe9d3", "#62cc71", "#ffadda",
        "#c884ff", "#badeff", "#bf8b6d", "#927acc", "#97ee3f", "#bf3947",
        "#9f5b00", "#f48758", "#8caed6", "#f2b94f", "#eff26e", "#e43872",
        "#d9b100", "#9d7a00", "#698cff", "#00d27e", "#d06800", "#009f82",
        "#c49200", "#cbe8ff", "#fecddf", "#c27eb6", "#8cd2ce", "#c4b8d9",
        "#f883b0", "#a49100", "#f48800", "#27d0df", "#a04a9b", "#4269d0",
    ]

    public static func defaultColor(at index: Int) -> String {
        defaultColors[((index % defaultColors.count) + defaultColors.count) % defaultColors.count]
    }
}
