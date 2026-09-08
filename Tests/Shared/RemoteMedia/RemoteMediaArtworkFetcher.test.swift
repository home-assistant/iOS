import Foundation
@testable import Shared
import Testing

/// Which sources the extension will fetch on its own.
///
/// It holds no Home Assistant credentials and the URL it is handed arrived over the air, so the
/// only safe posture is to fetch plainly or not at all.
struct RemoteMediaArtworkFetcherTests {
    @Test func aPublicHTTPSCoverIsFetchable() {
        #expect(RemoteMediaArtworkFetcher.isFetchable(
            URL(string: "https://is1-ssl.mzstatic.com/image/thumb/abc/600x600bb.jpg")!
        ))
    }

    @Test(arguments: [
        "http://cdn.example.com/art.jpg",
        "https://user:pw@cdn.example.com/art.jpg",
        "file:///etc/passwd",
        "data:image/png;base64,AAAA",
        "ftp://cdn.example.com/art.jpg",
    ])
    func everythingElseIsRefused(_ source: String) {
        guard let url = URL(string: source) else { return }
        #expect(!RemoteMediaArtworkFetcher.isFetchable(url))
    }

    /// Not a policy that can be relaxed quietly: a refused source returns no bytes rather than
    /// being fetched by some other path.
    @Test func arefusedSourceIsNotFetched() async {
        let data = await RemoteMediaArtworkFetcher.data(
            from: URL(string: "http://cdn.example.com/art.jpg")!
        )
        #expect(data == nil)
    }

    /// Artwork is optional, and the session must survive anything the origin does.
    @Test func anUnreachableOriginIsNotAnError() async {
        let data = await RemoteMediaArtworkFetcher.data(
            from: URL(string: "https://127.0.0.1:1/cover.jpg")!
        )
        #expect(data == nil)
    }

    /// The ledger is 6144 KB, so the ceiling is part of the contract rather than a detail.
    @Test func theSizeCeilingIsBounded() {
        #expect(RemoteMediaArtworkFetcher.maximumBytes <= 2 * 1024 * 1024)
        #expect(RemoteMediaArtworkFetcher.timeout <= 5)
    }

    /// Refused and unreachable sources are distinct outcomes for callers that want to explain a
    /// missing image without retrying an unsafe request.
    @Test func arefusalSaysWhy() async {
        let refused = await RemoteMediaArtworkFetcher.fetch(
            from: URL(string: "http://cdn.example.com/art.jpg")!
        )
        #expect(refused.data == nil)
        #expect(refused.reason == "refused source")
        #expect(refused.status == nil)

        let unreachable = await RemoteMediaArtworkFetcher.fetch(
            from: URL(string: "https://127.0.0.1:1/cover.jpg")!
        )
        #expect(unreachable.data == nil)
        #expect(unreachable.reason == "unreachable")
    }
}
