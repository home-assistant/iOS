import Foundation

/// Everything the previous app hands over, sealed as one blob.
struct AppMigrationPayload: Codable {
    static let currentVersion = 1

    struct KeychainItem: Codable {
        let store: AppMigrationKeychainStore
        let key: String
        let data: Data
    }

    let version: Int
    let sessionID: UUID
    let serverNames: [String]
    /// The complete GRDB file, taken with SQLite's online backup so it is consistent.
    let database: Data
    /// The app-group `UserDefaults` domain as a binary property list.
    let appGroupDefaults: Data
    let keychainItems: [KeychainItem]
    /// Raw `SensorPermission` values the previous app held; the new app asks for them again.
    let grantedPermissions: [String]?
}
