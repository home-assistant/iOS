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
    /// The servers the user turned the speaker on for, by server identifier. Empty until the user
    /// turns it on: it opens a listening socket on the local network.
    public var enabledServerIdentifiers: [String] = []
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
        let enabledServerIdentifiers: String? =
            row[DatabaseTables.SendspinPlayerConfiguration.enabledServerIdentifiers.rawValue]
        self.enabledServerIdentifiers = enabledServerIdentifiers
            .flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
        self.playerName = row[DatabaseTables.SendspinPlayerConfiguration.playerName.rawValue]
        self.volume = row[DatabaseTables.SendspinPlayerConfiguration.volume.rawValue] ?? 100
        self.isMuted = row[DatabaseTables.SendspinPlayerConfiguration.isMuted.rawValue] ?? false
        self.outputDelayMs = row[DatabaseTables.SendspinPlayerConfiguration.outputDelayMs.rawValue] ?? 0
        self.allowsUnpairedAccess = row[DatabaseTables.SendspinPlayerConfiguration.allowsUnpairedAccess.rawValue]
            ?? true
    }

    public init(
        id: String = SendspinPlayerConfiguration.singletonID,
        enabledServerIdentifiers: [String] = [],
        playerName: String? = nil,
        volume: Int = 100,
        isMuted: Bool = false,
        outputDelayMs: Int = 0,
        allowsUnpairedAccess: Bool = true
    ) {
        self.id = id
        self.enabledServerIdentifiers = enabledServerIdentifiers
        self.playerName = playerName
        self.volume = volume
        self.isMuted = isMuted
        self.outputDelayMs = outputDelayMs
        self.allowsUnpairedAccess = allowsUnpairedAccess
    }

    public var isEnabledForAnyServer: Bool {
        !enabledServerIdentifiers.isEmpty
    }

    public func isEnabled(forServerIdentifier identifier: String) -> Bool {
        enabledServerIdentifiers.contains(identifier)
    }

    public mutating func setEnabled(_ isEnabled: Bool, forServerIdentifier identifier: String) {
        enabledServerIdentifiers.removeAll { $0 == identifier }
        if isEnabled {
            enabledServerIdentifiers.append(identifier)
        }
    }
}
