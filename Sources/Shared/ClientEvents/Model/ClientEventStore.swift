import Foundation
import GRDB
import PromiseKit

public struct ClientEventStore {
    static var jsonCacheName = "clientEvents.json"
    public func addEvent(_ event: ClientEvent) {
        Current.Log.verbose("Adding event: \(event.text), \(event.jsonPayload)")
        let eventsCacheLimit = 1000
        var events = getEvents()
        events.append(event)
        if events.count > eventsCacheLimit {
            events = events.suffix(eventsCacheLimit)
        }
        saveJSONData(events)
    }

    public func getEvents() -> [ClientEvent] {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID) else {
            Current.Log.error("Failed to get container URL for get client events")
            return []
        }

        let fileURL = containerURL.appendingPathComponent(ClientEventStore.jsonCacheName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Current.Log.error("Client events cache file doesn't exist at path: \(fileURL.absoluteString)")
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
        saveJSONData([])
    }

    private func saveJSONData(_ events: [ClientEvent]) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID) else {
            Current.Log.error("Failed to get container URL for saving client events")
            return
        }

        let fileURL = containerURL.appendingPathComponent(ClientEventStore.jsonCacheName)

        do {
            let jsonData = try JSONEncoder().encode(events)
            try jsonData.write(to: fileURL)
            Current.Log.verbose("JSON saved successfully for client events, file URL: \(fileURL.absoluteString)")
        } catch {
            Current.Log.error("Error saving JSON for client events: \(error)")
        }
    }
}
