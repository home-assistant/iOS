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

    private static let eventsCacheLimit = 1000
    private static let trimCheckInterval = 100

    /// Events are recorded from every queue in the app (main, the WatchConnectivity callbacks, the
    /// expiring-activity queue, cooperative pool tasks). A serial queue keeps the file work off the
    /// recording thread — the very first event ("Application Starting") is recorded during app launch.
    private static let ioQueue = DispatchQueue(label: "io.home-assistant.client-event-store", qos: .utility)

    private static var appendsSinceTrim = 0
    private static var didConvertLegacyFile = false

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public func addEvent(_ event: ClientEvent) {
        Current.Log.verbose("Adding event: \(event.text), \(event.jsonPayload)")
        Self.ioQueue.async { [self] in
            convertLegacyFileIfNeeded()
            guard let line = encodedLine(for: event) else { return }
            appendLine(line)

            Self.appendsSinceTrim += 1
            if Self.appendsSinceTrim >= Self.trimCheckInterval {
                Self.appendsSinceTrim = 0
                trimToCacheLimit()
            }
        }
    }

    public func getEvents() -> [ClientEvent] {
        // Sync on the serial queue so pending `addEvent` writes are visible to this read.
        Self.ioQueue.sync {
            readEvents()
        }
    }

    public func clearAllEvents() {
        Self.ioQueue.sync {
            writeEvents([])
            Self.appendsSinceTrim = 0
            Self.didConvertLegacyFile = true
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
        guard !data.isEmpty else { return [] }

        if Self.isLegacyArray(data) {
            do {
                return try Self.decoder.decode([ClientEvent].self, from: data)
            } catch {
                Current.Log.error("Failed to decode client events data from cache, error: \(error)")
                return []
            }
        }

        return data.split(separator: UInt8(ascii: "\n")).compactMap { line in
            do {
                return try Self.decoder.decode(ClientEvent.self, from: Data(line))
            } catch {
                Current.Log.error("Failed to decode client event line, error: \(error)")
                return nil
            }
        }
    }

    /// A file written before events were stored one per line holds a single JSON array, and is
    /// rewritten once so appends never mix the two formats.
    private func convertLegacyFileIfNeeded() {
        guard !Self.didConvertLegacyFile else { return }
        Self.didConvertLegacyFile = true

        let fileURL = AppConstants.clientEventsFile
        guard let data = FileManager.default.contents(atPath: fileURL.path), Self.isLegacyArray(data) else {
            return
        }
        writeEvents(readEvents())
    }

    private static func isLegacyArray(_ data: Data) -> Bool {
        data.first == UInt8(ascii: "[")
    }

    private func encodedLine(for event: ClientEvent) -> Data? {
        do {
            var line = try Self.encoder.encode(event)
            line.append(UInt8(ascii: "\n"))
            return line
        } catch {
            Current.Log.error("Error encoding client event: \(error)")
            return nil
        }
    }

    /// Unsynchronized append; callers must be on `ioQueue`. `O_APPEND` keeps a write from another
    /// process in the app group from overwriting ours.
    private func appendLine(_ line: Data) {
        let fileURL = AppConstants.clientEventsFile
        let descriptor = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard descriptor >= 0 else {
            Current.Log.error("Error opening client events file for append, errno \(errno)")
            return
        }
        defer { close(descriptor) }

        // One `write` call, never a loop: `O_APPEND` makes a single write atomic against the other
        // processes in the app group, and resuming a partial one would let their bytes land in the
        // middle of this event. A short write drops the event instead of corrupting its neighbours.
        let written = line.withUnsafeBytes { buffer in
            buffer.baseAddress.map { write(descriptor, $0, buffer.count) } ?? 0
        }
        if written != line.count {
            Current.Log.error("Error appending client event, wrote \(written) of \(line.count), errno \(errno)")
        }
    }

    /// Unsynchronized write; callers must be on `ioQueue`.
    private func writeEvents(_ events: [ClientEvent]) {
        let fileURL = AppConstants.clientEventsFile
        var data = Data()
        for event in events {
            guard let line = encodedLine(for: event) else { continue }
            data.append(line)
        }
        do {
            // Atomic: the app group file is also read by the other processes sharing it (widgets, the
            // watch app), which must never observe a half-written file.
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Current.Log.error("Error saving client events: \(error)")
        }
    }

    /// Unsynchronized rewrite; callers must be on `ioQueue`.
    private func trimToCacheLimit() {
        let events = readEvents()
        guard events.count > Self.eventsCacheLimit else { return }
        writeEvents(Array(events.suffix(Self.eventsCacheLimit)))
    }
}
