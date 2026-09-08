import Foundation

/// Where this track's artwork can be found, and how to name it in the cache.
///
/// Two things produce one of these, and they know different amounts:
///
/// * the host app, which has already fetched and downsampled the image, supplies `cacheKey` and
///   nothing else — the file is on disk before the extension is asked for it;
/// * Home Assistant, pushing to a phone whose app is not running, supplies `url` and nothing else
///   — there is no host process to have prepared anything, so the extension fetches it itself.
///
/// `url` is only ever a credential-free absolute HTTPS source. A `media_player`'s
/// `entity_picture` is often a Home Assistant proxy path carrying a signed token, and these
/// attributes are serialized through Apple's infrastructure and echoed back by the push relay, so
/// that form is never put here. Where artwork exists only behind Home Assistant's own
/// authentication there is simply no `url`, and the extension shows none rather than leaking a
/// token to get one.
public struct RemoteMediaArtworkDescriptor: Codable, Equatable, Sendable {
    /// The cache file, when whoever built this had already written it.
    public let cacheKey: String?
    /// A source the extension may fetch with no credentials of any kind.
    public let url: URL?

    public init(cacheKey: String? = nil, url: URL? = nil) {
        self.cacheKey = cacheKey
        self.url = url
    }

    /// What the system keys its one-image-per-content-identity cache on.
    ///
    /// A track change has to change this or the previous song's cover stays on screen, and it must
    /// not contain a token, because the system is free to log or persist it.
    public var identity: String {
        cacheKey ?? url?.absoluteString ?? ""
    }
}
