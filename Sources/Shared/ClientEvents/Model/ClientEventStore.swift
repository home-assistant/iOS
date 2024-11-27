import Foundation
import PromiseKit
import GRDB

public struct ClientEventStore {
    
    public func addEvent(_ event: ClientEvent) -> Promise<Void> {
        do {
            try Current.database.write { db in
                try event.save(db)
            }
            cleanup()
        } catch {
            Current.Log.error("Failed to save client event: \(error)")
        }
        return .value(())
    }

    /// Keep only the last 1000 event entries
    private func cleanup() {
        do {
            try Current.database.write { db in
                let count = try ClientEvent.fetchCount(db)
                if count > 1000 {
                    let toDelete = count - 1000
                    try ClientEvent.order(Column("date")).limit(toDelete).deleteAll(db)
                }
            }
        } catch {
            Current.Log.error("Failed to cleanup client events: \(error)")
        }
    }

    public func getEvents(filter: String? = nil) -> [ClientEvent] {
        do {
            return try Current.database.read { db in
                try ClientEvent
                    .filter(Column("text") == filter)
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to save client event: \(error)")
            return []
        }
    }

    public func clearAllEvents() -> Promise<Void> {
        do {
            _ = try Current.database.write { db in
                try ClientEvent.deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to delete all client events: \(error)")
        }
        return .value(())
    }
}
