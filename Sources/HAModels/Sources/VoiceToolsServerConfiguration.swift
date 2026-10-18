import Foundation
import GRDB

/// Settings for the Wyoming voice server this device runs for Home Assistant.
///
/// Stored on its own rather than alongside `AssistConfiguration`: what this device offers Home
/// Assistant is independent of how Assist behaves inside the app, and a user is free to configure
/// one without the other. The `Current.database()`-backed accessors live in an extension in the app.
public struct VoiceToolsServerConfiguration: Codable, Identifiable, Equatable, PersistableRecord, FetchableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    public static let singletonID = "voice_tools_server_config"

    /// 10700 is the port Wyoming's own tooling defaults to, so a user adding the integration by
    /// hand will already have it typed in.
    public static let defaultPort = 10700

    public var id: String = VoiceToolsServerConfiguration.singletonID
    /// Off until the user turns it on: it opens a listening socket on the local network.
    public var isEnabled: Bool = false
    public var port: Int = VoiceToolsServerConfiguration.defaultPort

    /// Custom row initializer to handle NULL values from migrated columns.
    public init(row: Row) throws {
        self.id = row[DatabaseTables.VoiceToolsServerConfiguration.id.rawValue]
        self.isEnabled = row[DatabaseTables.VoiceToolsServerConfiguration.isEnabled.rawValue] ?? false
        self.port = row[DatabaseTables.VoiceToolsServerConfiguration.port.rawValue]
            ?? VoiceToolsServerConfiguration.defaultPort
    }

    public init(
        id: String = VoiceToolsServerConfiguration.singletonID,
        isEnabled: Bool = false,
        port: Int = VoiceToolsServerConfiguration.defaultPort
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.port = port
    }
}
