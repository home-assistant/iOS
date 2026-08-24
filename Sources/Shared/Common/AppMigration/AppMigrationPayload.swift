import Foundation

/// Everything the app being replaced hands to the app taking over.
///
/// The two heavy fields stay as opaque `Data` on purpose: `servers` is whatever
/// `ServerManager.restorableState()` produced and `configuration` is an `AppConfigurationTransfer`
/// export. Keeping them encoded means this envelope does not have to be revised every time either
/// of those shapes changes, and both sides already know how to read their own format.
public struct AppMigrationPayload: Codable, Equatable {
    public static let currentKind = "home-assistant-app-migration"
    public static let currentSchemaVersion = 1

    /// Marks the blob as a migration payload. A configuration export carries a different `kind`, so
    /// handing one to the migration importer is rejected instead of half-applied.
    public let kind: String
    public let schemaVersion: Int
    public let exportedAt: Date
    public let sourceBundleID: String
    public let sourceAppVersion: String

    /// `ServerManager.restorableState()`: every server with its connection details and tokens.
    public let servers: Data
    /// An `AppConfigurationTransfer` export, or `nil` when collecting it failed. A migration that
    /// carries the servers but not the configuration is still worth completing.
    public let configuration: Data?

    /// Counts captured at export time so the receiving app can describe the payload before applying
    /// it, without having to decode either blob first.
    public let serverCount: Int
    public let configurationEntryCount: Int

    public init(
        kind: String = AppMigrationPayload.currentKind,
        schemaVersion: Int = AppMigrationPayload.currentSchemaVersion,
        exportedAt: Date,
        sourceBundleID: String,
        sourceAppVersion: String,
        servers: Data,
        configuration: Data?,
        serverCount: Int,
        configurationEntryCount: Int
    ) {
        self.kind = kind
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.sourceBundleID = sourceBundleID
        self.sourceAppVersion = sourceAppVersion
        self.servers = servers
        self.configuration = configuration
        self.serverCount = serverCount
        self.configurationEntryCount = configurationEntryCount
    }
}
