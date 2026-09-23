import Foundation
import GRDB

public extension FrontendThemeVariable {
    /// Every property captured for one server in one appearance, keyed by property name.
    ///
    /// Returned as a dictionary because that is how it is consumed: a screen asks for one property
    /// at a time, and the caller caches the whole set rather than issuing a query per lookup.
    static func fetchVariables(
        serverId: String,
        appearance: FrontendThemeAppearance
    ) throws -> [String: FrontendThemeVariable] {
        let rows = try Current.database().read { db in
            try FrontendThemeVariable
                .filter(Column(DatabaseTables.FrontendThemeVariable.serverId.rawValue) == serverId)
                .filter(Column(DatabaseTables.FrontendThemeVariable.appearance.rawValue) == appearance)
                .fetchAll(db)
        }
        return Dictionary(rows.map { ($0.name, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    /// Every property captured for every server and appearance. Used by the provider's initial load.
    static func fetchAllVariables() throws -> [FrontendThemeVariable] {
        try Current.database().read { db in
            try FrontendThemeVariable.fetchAll(db)
        }
    }

    static func fetch(
        serverId: String,
        appearance: FrontendThemeAppearance,
        name: String
    ) throws -> FrontendThemeVariable? {
        try Current.database().read { db in
            try FrontendThemeVariable.fetchOne(
                db,
                key: identifier(serverId: serverId, appearance: appearance, name: name)
            )
        }
    }

    /// Replace everything stored for one server in one appearance with `variables`.
    ///
    /// The frontend always reports a whole theme, never a delta, so this is a replace rather than an
    /// upsert: a property the new theme stopped declaring has to disappear, or a screen would keep
    /// painting itself with a color the user no longer has. Both halves run in one transaction so a
    /// concurrent read never sees the gap between the delete and the insert.
    static func replaceAll(
        _ variables: [FrontendThemeVariable],
        serverId: String,
        appearance: FrontendThemeAppearance
    ) throws {
        try Current.database().write { db in
            try FrontendThemeVariable
                .filter(Column(DatabaseTables.FrontendThemeVariable.serverId.rawValue) == serverId)
                .filter(Column(DatabaseTables.FrontendThemeVariable.appearance.rawValue) == appearance)
                .deleteAll(db)
            for variable in variables {
                try variable.insert(db)
            }
        }
    }

    /// Drop every theme captured for a server. Called when the server is removed from the app.
    static func delete(serverId: String) {
        do {
            try Current.database().write { db in
                _ = try FrontendThemeVariable
                    .filter(Column(DatabaseTables.FrontendThemeVariable.serverId.rawValue) == serverId)
                    .deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to delete frontend theme variables for server, error: \(error)")
        }
    }
}
