import Foundation
@testable import Shared
import Testing

/// What crosses the RemoteMedia boundary with a track's artwork, and what the extension can do
/// with each form of it.
struct RemoteMediaArtworkDescriptorTests {
    private let sessionId = "4:homemedia_player.speaker"
    private let trackId = "7:track-15:Kids"

    /// The host app prepared the file, so the key is authoritative and no source is needed.
    @Test func aPreparedDescriptorKeepsItsKey() {
        let key = String(repeating: "a", count: 64)
        let descriptor = RemoteMediaArtworkDescriptor(cacheKey: key)
        #expect(descriptor.resolvedKey(sessionId: sessionId, trackId: trackId) == key)
        #expect(descriptor.identity == key)
    }

    /// A push from Home Assistant carries only a source. The extension has to be able to name the
    /// cache file itself, and to name the same one the host app would have.
    @Test func aPushedSourceDerivesTheKeyTheHostAppWouldHaveUsed() {
        let url = URL(string: "https://cdn.example.com/cover.jpg")!
        let descriptor = RemoteMediaArtworkDescriptor(url: url)
        let derived = descriptor.resolvedKey(sessionId: sessionId, trackId: trackId)
        #expect(derived == RemoteMediaArtworkCache.key(
            sessionId: sessionId,
            trackId: trackId,
            source: url.absoluteString
        ))
    }

    /// The system caches one image per content identity, so this changing is what replaces the
    /// previous song's cover.
    @Test func adifferentCoverIsADifferentIdentity() {
        let first = RemoteMediaArtworkDescriptor(url: URL(string: "https://cdn.example.com/a.jpg")!)
        let second = RemoteMediaArtworkDescriptor(url: URL(string: "https://cdn.example.com/b.jpg")!)
        #expect(first.identity != second.identity)
    }

    @Test func anEmptyDescriptorNamesNothing() {
        let descriptor = RemoteMediaArtworkDescriptor()
        #expect(descriptor.resolvedKey(sessionId: sessionId, trackId: trackId) == nil)
        #expect(RemoteMediaArtworkCache.url(for: descriptor) == nil)
    }

    /// A descriptor that only ever carried a source must not be able to name a file, or a URL
    /// could be made to address something outside the cache directory.
    @Test func aSourceAloneCannotAddressAFile() {
        let descriptor = RemoteMediaArtworkDescriptor(url: URL(string: "https://cdn.example.com/a.jpg")!)
        #expect(RemoteMediaArtworkCache.url(for: descriptor) == nil)
    }

    @Test func aKeyThatIsNotADigestCannotAddressAFile() {
        for key in ["../../etc/passwd", "", "zz", String(repeating: "g", count: 64)] {
            let descriptor = RemoteMediaArtworkDescriptor(cacheKey: key)
            #expect(RemoteMediaArtworkCache.url(for: descriptor) == nil, "\(key)")
        }
    }

    /// The wire form the Home Assistant side produces.
    @Test func aPushedDescriptorDecodesFromTheServerShape() throws {
        let json = Data(#"{"url":"https://cdn.example.com/cover.jpg"}"#.utf8)
        let descriptor = try JSONDecoder().decode(RemoteMediaArtworkDescriptor.self, from: json)
        #expect(descriptor.url?.absoluteString == "https://cdn.example.com/cover.jpg")
        #expect(descriptor.cacheKey == nil)
    }
}
