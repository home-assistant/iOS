import Foundation

/// Holds the slices of a payload while it is being handed over, on both sides of the migration.
///
/// Persisted rather than kept in memory: every chunk costs an app switch, and the app that is not in
/// front may be terminated between round trips. Keyed by session so an abandoned attempt cannot
/// contribute slices to a later one.
public enum AppMigrationChunkStore {
    private static let sessionKey = "appMigrationChunkSession"
    private static let chunksKey = "appMigrationChunks"
    private static let totalKey = "appMigrationChunkTotal"

    private static var prefs: UserDefaults { Current.settingsStore.prefs }

    /// Stores `chunk`, discarding anything held for a different session. Returns the assembled
    /// payload string once every slice has arrived, or `nil` while any are still missing.
    public static func accept(_ chunk: AppMigrationChunk) -> String? {
        if prefs.string(forKey: sessionKey) != chunk.sessionID {
            Current.Log.info("Starting app migration chunk session \(chunk.sessionID)")
            clear()
            prefs.set(chunk.sessionID, forKey: sessionKey)
            prefs.set(chunk.total, forKey: totalKey)
        }

        var chunks = prefs.dictionary(forKey: chunksKey) as? [String: String] ?? [:]
        chunks[String(chunk.index)] = chunk.data
        prefs.set(chunks, forKey: chunksKey)
        Current.Log.info("Received app migration chunk \(chunk.index + 1)/\(chunk.total)")

        guard chunks.count == chunk.total else { return nil }

        // Reassemble in index order — the dictionary is unordered and the chunks may well have
        // arrived out of it if a round trip was retried.
        let assembled = (0 ..< chunk.total).compactMap { chunks[String($0)] }
        guard assembled.count == chunk.total else {
            Current.Log.error("App migration chunk set is complete by count but not by index")
            return nil
        }
        clear()
        return assembled.joined()
    }

    /// Which slices of `sessionID` have already arrived, so a resumed handoff can skip them.
    public static func receivedIndices(forSession sessionID: String) -> Set<Int> {
        guard prefs.string(forKey: sessionKey) == sessionID,
              let chunks = prefs.dictionary(forKey: chunksKey) as? [String: String] else {
            return []
        }
        return Set(chunks.keys.compactMap(Int.init))
    }

    public static func clear() {
        prefs.removeObject(forKey: sessionKey)
        prefs.removeObject(forKey: chunksKey)
        prefs.removeObject(forKey: totalKey)
    }
}
