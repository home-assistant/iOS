import Foundation
import GRDB
import PromiseKit

public protocol ClientEventStoreProtocol {
    func addEvent(_ event: ClientEvent)
    func getEvents() -> [ClientEvent]
    func clearAllEvents()
}

final class ClientEventStore: ClientEventStoreProtocol {
    static var jsonCacheName = "databases/clientEvents.json"
    /// Events are recorded from every queue in the app (main, the WatchConnectivity callbacks, the
    /// expiring-activity queue, cooperative pool tasks). Appending is a read-modify-write of one shared
    /// file, so without serialization concurrent writers lose each other's events — and a reader
    /// landing mid-write decodes a truncated file, which throws away the whole history.
    ///
    /// A serial queue (instead of a lock held on the caller's thread) also keeps the cost off the
    /// recording thread: every append decodes and atomically rewrites a file holding up to 1000
    /// events, which is far too slow for the main thread — the very first event ("Application
    /// Starting") is recorded during app launch.
    private static let ioQueue = DispatchQueue(label: "io.home-assistant.client-event-store", qos: .utility)

    public func addEvent(_ event: ClientEvent) {
        Current.Log.verbose("Adding event: \(event.text), \(event.jsonPayload)")
        let eventsCacheLimit = 1000
        Self.ioQueue.async { [self] in
            var events = readEvents()
            events.append(event)
            if events.count > eventsCacheLimit {
                events = Array(events.suffix(eventsCacheLimit))
            }
            saveJSONData(events)
        }
    }

    public func getEvents() -> [ClientEvent] {
        // Sync on the serial queue so pending `addEvent` writes are visible to this read.
        Self.ioQueue.sync {
            readEvents()
        }
    }

    /// Unsynchronized read; callers must be on `ioQueue`.
    private func readEvents() -> [ClientEvent] {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID) else {
            Current.Log.error("Failed to get container URL for get client events")
            return []
        }

        let fileURL = containerURL.appendingPathComponent(ClientEventStore.jsonCacheName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Expected until the first event is recorded after a fresh install or a cache clear.
            Current.Log.info("Client events cache file doesn't exist yet at path: \(fileURL.absoluteString)")
            return []
        }

        let data = FileManager.default.contents(atPath: fileURL.path) ?? Data()

        do {
            let clientEvents = try JSONDecoder().decode([ClientEvent].self, from: data)
            return clientEvents
        } catch {
            Current.Log.error("Failed to decode client events data from cache, error: \(error)")
            return []
        }
    }

    public func clearAllEvents() {
        Self.ioQueue.sync {
            saveJSONData([])
        }
    }

    /// Unsynchronized write; callers must be on `ioQueue`.
    private func saveJSONData(_ events: [ClientEvent]) {
        do {
            let fileURL = AppConstants.clientEventsFile
            let jsonData = try JSONEncoder().encode(events)
            // Atomic: the app group file is also read by the other processes sharing it (widgets, the
            // watch app), which must never observe a half-written array.
            try jsonData.write(to: fileURL, options: .atomic)
            Current.Log.verbose("JSON saved successfully for client events, file URL: \(fileURL.absoluteString)")
        } catch {
            Current.Log.error("Error saving JSON for client events: \(error)")
        }
    }
}
