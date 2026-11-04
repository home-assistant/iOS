import Foundation
import GRDB

/// A single CSS custom property resolved by the Home Assistant frontend, captured so native
/// screens can be drawn in the colors the user configured rather than the app's own defaults.
///
/// The frontend is the only place a theme exists: it merges the user's selected theme over the
/// defaults shipped in `color.globals.ts` and resolves every `var()` chain in the browser. Rather
/// than reimplement that, the web view reports what it computed and each property lands here as a
/// row, keyed per server (every server carries its own theme) and per ``FrontendThemeAppearance``.
///
/// ``value`` is the raw computed CSS string, so non-color properties (lengths, fonts, radii)
/// survive too. ``colorValue`` is the canonical `rgb()`/`rgba()` form the browser produced, and is
/// `nil` for anything that is not a color — which is what makes it safe to hand straight to a
/// color parser.
public struct FrontendThemeVariable: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    public static let databaseTableName = GRDBDatabaseTable.frontendThemeVariable.rawValue

    /// `serverId|appearance|name`, so re-capturing a theme overwrites in place instead of accumulating.
    public var id: String
    public var serverId: String
    public var appearance: FrontendThemeAppearance
    /// The custom property name, including the leading dashes — for example `--primary-color`.
    public var name: String
    /// The computed CSS value, as the browser resolved it.
    public var value: String
    /// The canonical `rgb()`/`rgba()` value, or `nil` when the property is not a color.
    public var colorValue: String?
    /// The name of the theme that was active when this was captured, when the frontend exposed it.
    public var themeName: String?
    public var updatedAt: Date

    public init(
        serverId: String,
        appearance: FrontendThemeAppearance,
        name: String,
        value: String,
        colorValue: String? = nil,
        themeName: String? = nil,
        updatedAt: Date
    ) {
        self.id = Self.identifier(serverId: serverId, appearance: appearance, name: name)
        self.serverId = serverId
        self.appearance = appearance
        self.name = name
        self.value = value
        self.colorValue = colorValue
        self.themeName = themeName
        self.updatedAt = updatedAt
    }

    public static func identifier(serverId: String, appearance: FrontendThemeAppearance, name: String) -> String {
        "\(serverId)|\(appearance.rawValue)|\(name)"
    }
}
