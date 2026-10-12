import Foundation
import GRDB

/// Settings for the Sendspin player this device offers Music Assistant.
///
/// The keys and pairing records the connection's encryption rests on are secrets and live in the
/// keychain, not here. The `Current.database()`-backed accessors live in an extension in the app.
public struct SendspinPlayerConfiguration: Codable, Identifiable, Equatable, PersistableRecord, FetchableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    public static let singletonID = "sendspin_player_config"
    public static let maximumOutputDelayMs = 5000

    public var id: String = SendspinPlayerConfiguration.singletonID
    /// Off until the user turns it on: it opens a listening socket on the local network.
    public var isEnabled: Bool = false
    /// The name Music Assistant shows for this player. `nil` follows the device name.
    public var playerName: String?
    /// 0-100, as perceived loudness. Kept across launches, as the specification recommends.
    public var volume: Int = 100
    public var isMuted: Bool = false
    /// Extra delay past the device's own audio output, such as an external speaker adds.
    public var outputDelayMs: Int = 0
    /// Whether a server that has not paired may play here once its operator approves the device.
    public var allowsUnpairedAccess: Bool = true

    /// Custom row initializer to handle NULL values from migrated columns.
    public init(row: Row) throws {
        self.id = row[DatabaseTables.SendspinPlayerConfiguration.id.rawValue]
        self.isEnabled = row[DatabaseTables.SendspinPlayerConfiguration.isEnabled.rawValue] ?? false
        self.playerName = row[DatabaseTables.SendspinPlayerConfiguration.playerName.rawValue]
        self.volume = row[DatabaseTables.SendspinPlayerConfiguration.volume.rawValue] ?? 100
        self.isMuted = row[DatabaseTables.SendspinPlayerConfiguration.isMuted.rawValue] ?? false
        self.outputDelayMs = row[DatabaseTables.SendspinPlayerConfiguration.outputDelayMs.rawValue] ?? 0
        self.allowsUnpairedAccess = row[DatabaseTables.SendspinPlayerConfiguration.allowsUnpairedAccess.rawValue]
            ?? true
    }

    public init(
        id: String = SendspinPlayerConfiguration.singletonID,
        isEnabled: Bool = false,
        playerName: String? = nil,
        volume: Int = 100,
        isMuted: Bool = false,
        outputDelayMs: Int = 0,
        allowsUnpairedAccess: Bool = true
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.playerName = playerName
        self.volume = volume
        self.isMuted = isMuted
        self.outputDelayMs = outputDelayMs
        self.allowsUnpairedAccess = allowsUnpairedAccess
    }
}
