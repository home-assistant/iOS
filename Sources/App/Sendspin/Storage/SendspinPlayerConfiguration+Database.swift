import Foundation
import GRDB
import Shared

// `SendspinPlayerConfiguration` itself lives in the `HAModels` package; these are its
// database-backed accessors.
extension SendspinPlayerConfiguration {
    static var config: SendspinPlayerConfiguration {
        do {
            return try Current.database().read { db in
                try SendspinPlayerConfiguration.fetchOne(db, key: SendspinPlayerConfiguration.singletonID)
            } ?? SendspinPlayerConfiguration()
        } catch {
            Current.Log.error("Failed to fetch SendspinPlayerConfiguration: \(error)")
            assertionFailure("Failed to fetch SendspinPlayerConfiguration: \(error)")
            return SendspinPlayerConfiguration()
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try save(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save SendspinPlayerConfiguration: \(error)")
            assertionFailure("Failed to save SendspinPlayerConfiguration: \(error)")
        }
    }

    /// The name servers see: the one the user typed, or else the device's.
    var resolvedPlayerName: String {
        let trimmed = playerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? WyomingServiceCatalog.advertisedDeviceName() : trimmed
    }

    var playerSettings: SendspinPlayerSettings {
        SendspinPlayerSettings(
            name: resolvedPlayerName,
            volume: min(max(volume, 0), 100),
            isMuted: isMuted,
            outputDelayMs: min(max(outputDelayMs, 0), Self.maximumOutputDelayMs),
            allowsUnpairedAccess: allowsUnpairedAccess
        )
    }
}
