import CryptoKit
import Foundation

/// Disk-backed byte cache.
///
/// Keys are opaque to the protocol; use `notificationIconCacheKey(for:)` to derive
/// the canonical key for a URL so different callers reach the same entry.
public protocol NotificationIconCache {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data, forKey key: String)
}

/// Canonical cache key for a notification-icon URL. SHA-256 of the absolute URL
/// string with a `.img` suffix. Lives at module scope so callers don't need to
/// reference any concrete cache implementation.
public func notificationIconCacheKey(for url: URL) -> String {
    let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
    return digest.map { String(format: "%02x", $0) }.joined() + ".img"
}

public final class NotificationIconCacheImpl: NotificationIconCache {
    private let directory: URL
    private let maxEntries: Int
    private let queue = DispatchQueue(label: "io.home-assistant.NotificationIconCache")
    /// Cross-process coordinator: the App Group container is shared between the host app,
    /// the Notification Service Extension, and Watch extensions. The serial queue alone
    /// only guarantees ordering within this process.
    private let coordinator = NSFileCoordinator()

    public convenience init() {
        let dir = AppConstants.AppGroupContainer
            .appendingPathComponent("notification-icons", isDirectory: true)
        self.init(directory: dir, maxEntries: 50)
    }

    init(directory: URL, maxEntries: Int) {
        self.directory = directory
        self.maxEntries = maxEntries
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Current.Log.error("NotificationIconCache: failed to create directory \(directory.path): \(error)")
        }
    }

    public func data(forKey key: String) -> Data? {
        queue.sync {
            let url = directory.appendingPathComponent(key)
            var read: Data?
            var coordinatorError: NSError?
            coordinator.coordinate(readingItemAt: url, error: &coordinatorError) { coordinatedURL in
                read = try? Data(contentsOf: coordinatedURL)
            }
            guard let data = read else { return nil }
            // Best-effort mtime touch so LRU tracks reads as well as writes.
            // Failure here only means this entry may be evicted slightly earlier — not a
            // correctness concern, so no log.
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: url.path
            )
            return data
        }
    }

    public func setData(_ data: Data, forKey key: String) {
        queue.sync {
            let url = directory.appendingPathComponent(key)
            var writeError: Error?
            var coordinatorError: NSError?
            coordinator
                .coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
                    do {
                        try data.write(to: coordinatedURL, options: .atomic)
                    } catch {
                        writeError = error
                    }
                }
            if let error = (writeError ?? coordinatorError) {
                Current.Log.error("NotificationIconCache: write failed for key \(key): \(error)")
            }
            prune()
        }
    }

    /// Drop the oldest files until count <= maxEntries. Must be called on `queue`.
    private func prune() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        guard entries.count > maxEntries else { return }

        // Snapshot (url, mtime) once per entry, then sort — avoids re-stat'ing inside
        // the comparator and keeps the prefetched cache from `contentsOfDirectory` the
        // sole source of mtimes.
        let dated = entries.map { url -> (URL, Date) in
            let date = (
                try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate
            ) ?? .distantPast
            return (url, date)
        }
        let sorted = dated.sorted { $0.1 < $1.1 }.map(\.0)
        for url in sorted.prefix(entries.count - maxEntries) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
