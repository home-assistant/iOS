import Foundation
@testable import Shared
import Testing

/// What crosses the RemoteMedia boundary with a track's artwork, and what the extension can do
/// with each form of it.
struct RemoteMediaArtworkDescriptorTests {
    @Test func aPreparedDescriptorKeepsItsKeyAsItsIdentity() {
        let key = String(repeating: "a", count: 64)
        #expect(RemoteMediaArtworkDescriptor(cacheKey: key).identity == key)
    }

    /// The system caches one image per content identity, so this changing is what replaces the
    /// previous song's cover.
    @Test func adifferentCoverIsADifferentIdentity() {
        let first = RemoteMediaArtworkDescriptor(url: URL(string: "https://cdn.example.com/a.jpg")!)
        let second = RemoteMediaArtworkDescriptor(url: URL(string: "https://cdn.example.com/b.jpg")!)
        #expect(first.identity != second.identity)
    }

    @Test func anEmptyDescriptorHasNoIdentity() {
        let descriptor = RemoteMediaArtworkDescriptor()
        #expect(descriptor.identity.isEmpty)
    }

    /// The wire form the Home Assistant side produces.
    @Test func aPushedDescriptorDecodesFromTheServerShape() throws {
        let json = Data(#"{"url":"https://cdn.example.com/cover.jpg"}"#.utf8)
        let descriptor = try JSONDecoder().decode(RemoteMediaArtworkDescriptor.self, from: json)
        #expect(descriptor.url?.absoluteString == "https://cdn.example.com/cover.jpg")
        #expect(descriptor.cacheKey == nil)
    }
}
