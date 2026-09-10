import CryptoKit
import Foundation

/// The App Group directory the host app writes prepared artwork into and the extension reads from.
/// The extension only reads prepared bytes, keeping image decoding out of its 6144 KB memory budget.
public enum RemoteMediaArtworkCache {
    /// How many prepared images to keep. Enough for the current track plus recent history, so
    /// skipping back and forth does not refetch, and bounded so the group container cannot grow.
    static let maximumEntries = 8

    public static var directoryURL: URL? {
        RemoteMediaAppGroup.containerURL?
            .appendingPathComponent("Library/Caches/RemoteMediaArtwork", isDirectory: true)
    }

    /// A stable name for one track's artwork. Changing track or artwork source changes the key, so
    /// the extension can never be handed the previous track's image.
    public static func key(sessionId: String, trackId: String, source: String) -> String {
        let identity = "\(sessionId.utf8.count):\(sessionId)\(trackId.utf8.count):\(trackId)\(source)"
        let digest = SHA256.hash(data: Data(identity.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func url(for descriptor: RemoteMediaArtworkDescriptor) -> URL? {
        // Guard against a key that is not the hex digest this cache writes, so a malformed
        // descriptor — or one that only ever carried a source — cannot reach outside the cache
        // directory.
        guard let key = descriptor.cacheKey else { return nil }
        guard key.count == 64, key.allSatisfy(\.isHexDigit) else { return nil }
        return directoryURL?.appendingPathComponent(key, isDirectory: false)
    }

    /// The cached bytes, or `nil` when nothing usable is there. Missing and unreadable are the same
    /// answer on purpose: artwork is optional and must never fail a session.
    public static func data(for descriptor: RemoteMediaArtworkDescriptor) -> Data? {
        guard let url = url(for: descriptor) else { return nil }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data
    }

    /// Whether prepared artwork is already on disk, without reading it. The host checks this on the
    /// main actor before publishing, so it must not pull the image into memory.
    public static func contains(_ descriptor: RemoteMediaArtworkDescriptor) -> Bool {
        guard let url = url(for: descriptor) else { return false }
        let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        return (size ?? 0) > 0
    }

    public static func store(_ data: Data, for descriptor: RemoteMediaArtworkDescriptor) throws {
        guard let directory = directoryURL, let url = url(for: descriptor) else {
            RemoteMediaLog.logger.error("artwork store result=no cache location")
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        prune(in: directory, keeping: url)
    }

    /// Drops the least recently modified entries beyond `maximumEntries`.
    ///
    /// `keeping` is never evicted. Modification dates have coarse resolution, so several images
    /// written in the same instant — a user skipping tracks quickly — sort arbitrarily, and without
    /// this the image just written could be the one thrown away, leaving the current track blank.
    static func prune(in directory: URL, keeping: URL? = nil) {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ), entries.count > maximumEntries else { return }

        let sorted = entries.sorted { left, right in
            let leftDate = (try? left.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? .distantPast
            return leftDate > rightDate
        }
        let keepPath = keeping?.standardizedFileURL.path
        var budget = maximumEntries
        if let keepPath, sorted.contains(where: { $0.standardizedFileURL.path == keepPath }) {
            budget -= 1
        }
        var kept = 0
        for url in sorted where url.standardizedFileURL.path != keepPath {
            guard kept >= budget else {
                kept += 1
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    public static func removeAll() {
        guard let directory = directoryURL else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
