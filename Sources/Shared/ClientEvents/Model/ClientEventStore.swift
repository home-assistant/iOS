import Foundation
import GRDB
import PromiseKit

public struct ClientEventStore {
    public var addEvent: ((_ event: ClientEvent) -> Promise<Void>) = { event in
        Current.Log.verbose("Adding client event: \(event)")
        do {
            try Current.database.write { db in
                try event.save(db)
            }
            Current.clientEventStore.cleanup()
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

    public func getEvents() -> [ClientEvent] {
        do {
            return try Current.database.read { db in
                try ClientEvent
                    .order(Column(DatabaseTables.ClientEvent.date.rawValue).desc)
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
