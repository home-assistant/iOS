import Foundation
@testable import Shared
import Testing

@Suite(.serialized)
struct RemoteMediaArtworkCacheTests {
    private func descriptor(track: String = "track", source: String = "/art.png") -> RemoteMediaArtworkDescriptor {
        .init(cacheKey: RemoteMediaArtworkCache.key(sessionId: "session", trackId: track, source: source))
    }

    @Test func keyChangesWithTrackAndWithArtworkSource() {
        let base = RemoteMediaArtworkCache.key(sessionId: "s", trackId: "t", source: "/a.png")
        #expect(RemoteMediaArtworkCache.key(sessionId: "s", trackId: "t2", source: "/a.png") != base)
        #expect(RemoteMediaArtworkCache.key(sessionId: "s", trackId: "t", source: "/b.png") != base)
        #expect(RemoteMediaArtworkCache.key(sessionId: "s2", trackId: "t", source: "/a.png") != base)
        #expect(RemoteMediaArtworkCache.key(sessionId: "s", trackId: "t", source: "/a.png") == base)
    }

    /// A session id and a track id that run together must not collide with a different split of the
    /// same characters, or one track could be served another's art.
    @Test func keyIsUnambiguousAcrossFieldBoundaries() {
        #expect(
            RemoteMediaArtworkCache.key(sessionId: "ab", trackId: "c", source: "/x") !=
                RemoteMediaArtworkCache.key(sessionId: "a", trackId: "bc", source: "/x")
        )
    }

    @Test func storedArtworkIsReadBackAndStaleArtworkIsNotReused() throws {
        let first = descriptor(track: "one")
        let second = descriptor(track: "two")
        defer { RemoteMediaArtworkCache.removeAll() }

        try RemoteMediaArtworkCache.store(Data("first".utf8), for: first)
        #expect(RemoteMediaArtworkCache.data(for: first) == Data("first".utf8))
        // A track with no cached art reads as absent rather than falling back to the previous one.
        #expect(RemoteMediaArtworkCache.data(for: second) == nil)
    }

    @Test func missingAndCorruptEntriesReadAsAbsent() throws {
        defer { RemoteMediaArtworkCache.removeAll() }
        #expect(RemoteMediaArtworkCache.data(for: descriptor(track: "absent")) == nil)

        let empty = descriptor(track: "empty")
        try RemoteMediaArtworkCache.store(Data(), for: empty)
        #expect(RemoteMediaArtworkCache.data(for: empty) == nil)
    }

    @Test func aMalformedKeyCannotEscapeTheCacheDirectory() {
        #expect(RemoteMediaArtworkCache.url(for: .init(cacheKey: "../../etc/passwd")) == nil)
        #expect(RemoteMediaArtworkCache.url(for: .init(cacheKey: "short")) == nil)
        #expect(RemoteMediaArtworkCache.url(for: .init(cacheKey: String(repeating: "z", count: 64))) == nil)
        #expect(RemoteMediaArtworkCache.url(for: descriptor()) != nil)
    }

    @Test func cacheStaysBounded() throws {
        defer { RemoteMediaArtworkCache.removeAll() }
        let directory = try #require(RemoteMediaArtworkCache.directoryURL)
        let last = RemoteMediaArtworkCache.maximumEntries + 4
        for index in 0 ... last {
            try RemoteMediaArtworkCache.store(Data("art\(index)".utf8), for: descriptor(track: "t\(index)"))
        }
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(remaining.count <= RemoteMediaArtworkCache.maximumEntries)
        // Writes land within the same modification-date tick, so the entry just stored is the one
        // that must survive: it is the track currently playing.
        #expect(RemoteMediaArtworkCache.data(for: descriptor(track: "t\(last)")) == Data("art\(last)".utf8))
    }

    /// With distinct timestamps, pruning keeps the newest and drops the oldest.
    @Test func pruningKeepsTheMostRecentEntries() throws {
        defer { RemoteMediaArtworkCache.removeAll() }
        let directory = try #require(RemoteMediaArtworkCache.directoryURL)
        let total = RemoteMediaArtworkCache.maximumEntries + 3
        for index in 0 ..< total {
            let entry = descriptor(track: "p\(index)")
            try RemoteMediaArtworkCache.store(Data("art\(index)".utf8), for: entry)
            let url = try #require(RemoteMediaArtworkCache.url(for: entry))
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(Double(index))],
                ofItemAtPath: url.path
            )
        }
        RemoteMediaArtworkCache.prune(in: directory)
        #expect(RemoteMediaArtworkCache.data(for: descriptor(track: "p\(total - 1)")) != nil)
        #expect(RemoteMediaArtworkCache.data(for: descriptor(track: "p0")) == nil)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(remaining.count == RemoteMediaArtworkCache.maximumEntries)
    }

    @Test func downsampleHonoursItsBoundAndNeverUpscales() throws {
        let large = try #require(RemoteMediaArtworkPreparerTestSupport.png(width: 900, height: 600))
        let downsampled = try #require(RemoteMediaArtworkPreparer.downsample(large, maximumPixelSize: 512))
        let size = try #require(RemoteMediaArtworkPreparerTestSupport.pixelSize(of: downsampled))
        #expect(max(size.width, size.height) == 512)

        let small = try #require(RemoteMediaArtworkPreparerTestSupport.png(width: 64, height: 64))
        let untouched = try #require(RemoteMediaArtworkPreparer.downsample(small, maximumPixelSize: 512))
        let smallSize = try #require(RemoteMediaArtworkPreparerTestSupport.pixelSize(of: untouched))
        #expect(smallSize == CGSize(width: 64, height: 64))
    }

    @Test func downsampleRejectsSomethingThatIsNotAnImage() {
        #expect(RemoteMediaArtworkPreparer.downsample(Data("not an image".utf8)) == nil)
    }
}
