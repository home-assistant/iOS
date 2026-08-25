import Foundation
import Shared

/// Holds database mirrors the iPhone pushed while the watch app was backgrounded, until a task with
/// a budget large enough to decode and apply them runs. Decoding one inside the WatchConnectivity
/// delivery itself exhausts that action's 2 second CPU allowance and the app is killed.
enum PushedMirrorStagingStore {
    struct Entry {
        let data: Data
        let metadata: HAWatchConnectivity.Content?
    }

    private static let directoryName = "pushedMirrors"
    private static let fileExtension = "plist"
    private static let entryLimit = 10

    private enum Key {
        static let content = "content"
        static let metadata = "metadata"
    }

    static func store(data: Data, metadata: HAWatchConnectivity.Content?) {
        guard let directory = directoryURL() else { return }

        var payload: [String: Any] = [Key.content: data]
        if let metadata {
            payload[Key.metadata] = metadata
        }

        let name = String(format: "%020.6f-%@", Current.date().timeIntervalSince1970, UUID().uuidString)
        let fileURL = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        do {
            let serialized = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
            try serialized.write(to: fileURL, options: .atomic)
            Current.Log.info("Staged pushed watch database mirror (\(data.count) bytes) for later apply")
        } catch {
            Current.Log.error("Failed to stage pushed watch database mirror: \(error)")
            return
        }

        dropEntriesOverLimit()
    }

    /// Returns the staged mirrors in arrival order and removes them, so a failed apply doesn't
    /// replay forever. The phone re-sends anything the watch is missing on its next sync request.
    static func takeAll() -> [Entry] {
        guard let directory = directoryURL() else { return [] }

        return stagedFileURLs(in: directory).compactMap { fileURL in
            defer { try? FileManager.default.removeItem(at: fileURL) }
            guard let serialized = try? Data(contentsOf: fileURL),
                  let payload = try? PropertyListSerialization.propertyList(
                      from: serialized,
                      options: [],
                      format: nil
                  ) as? [String: Any],
                  let data = payload[Key.content] as? Data else {
                Current.Log.error("Discarding unreadable staged watch database mirror at \(fileURL.lastPathComponent)")
                return nil
            }
            return Entry(data: data, metadata: payload[Key.metadata] as? HAWatchConnectivity.Content)
        }
    }

    static var hasStagedMirrors: Bool {
        guard let directory = directoryURL() else { return false }
        return !stagedFileURLs(in: directory).isEmpty
    }

    private static func stagedFileURLs(in directory: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.pathExtension == fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func dropEntriesOverLimit() {
        guard let directory = directoryURL() else { return }
        let urls = stagedFileURLs(in: directory)
        guard urls.count > entryLimit else { return }
        for url in urls.prefix(urls.count - entryLimit) {
            Current.Log.error("Dropping staged watch database mirror \(url.lastPathComponent), too many pending")
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func directoryURL() -> URL? {
        let directory = AppConstants.AppGroupContainer.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create staged watch database mirror directory: \(error)")
                return nil
            }
        }
        return directory
    }
}
