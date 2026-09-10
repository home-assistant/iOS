import Foundation

public extension RemoteMediaArtworkDescriptor {
    /// The cache file for this artwork, deriving one from its credential-free source when needed.
    ///
    /// A host-prepared descriptor already carries the key. A descriptor received on a cold launch
    /// carries only a public URL, so deriving the same key lets a prepared image be reused without
    /// putting the source itself in the cache path.
    func resolvedKey(sessionId: String, trackId: String) -> String? {
        if let cacheKey { return cacheKey }
        guard let url else { return nil }
        return RemoteMediaArtworkCache.key(
            sessionId: sessionId,
            trackId: trackId,
            source: url.absoluteString
        )
    }
}
