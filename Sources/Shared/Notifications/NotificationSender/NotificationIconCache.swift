import CryptoKit
import Foundation

public protocol NotificationIconCache {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data, forKey key: String)
}

public func notificationIconCacheKey(for url: URL, serverID: String? = nil) -> String {
    let stringToHash: String
    if let serverID {
        stringToHash = "\(serverID)|\(url.absoluteString)"
    } else {
        stringToHash = url.absoluteString
    }
    let digest = SHA256.hash(data: Data(stringToHash.utf8))
    return digest.map { String(format: "%02x", $0) }.joined() + ".img"
}

public final class NotificationIconCacheImpl: NotificationIconCache {
    private let directory: URL
    private let maxEntries: Int
    private let queue = DispatchQueue(label: "io.home-assistant.NotificationIconCache")
    // The serial queue does not coordinate access between the app and its extensions.
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

    private func prune() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        guard entries.count > maxEntries else { return }

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
