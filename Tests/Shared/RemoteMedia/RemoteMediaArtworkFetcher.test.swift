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
        "https:///art.jpg",
    ])
    func nonHTTPSOrCredentialedURLsAreRefused(_ source: String) {
        guard let url = URL(string: source) else { return }
        #expect(!RemoteMediaArtworkFetcher.isFetchable(url))
    }

    @Test(arguments: [
        "https://8.8.8.8/art.jpg",
        "https://93.184.216.34/art.jpg",
        "https://8.19.2.1/art.jpg",
        "https://8.8.2.2/art.jpg",
    ])
    func publicIPAddressesRemainFetchable(_ source: String) {
        #expect(RemoteMediaArtworkFetcher.isFetchable(URL(string: source)!))
    }

    /// Not a policy that can be relaxed quietly: a refused source returns no bytes rather than
    /// being fetched by some other path.
    @Test func aRefusedSourceIsNotFetched() async {
        let data = await RemoteMediaArtworkFetcher.data(
            from: URL(string: "http://cdn.example.com/art.jpg")!
        )
        #expect(data == nil)
    }

    @Test func localArtworkDestinationsAreAllowed() async {
        let validator = RemoteMediaArtworkDestinationValidator()
        for source in [
            "https://localhost/art.jpg",
            "https://127.0.0.1/art.jpg",
            "https://10.0.0.2/art.jpg",
            "https://192.168.1.2/art.jpg",
            "https://music.lan/art.jpg",
            "https://[::1]/art.jpg",
            "https://[fe80::1]/art.jpg",
        ] {
            let isAllowed = await validator.allows(URL(string: source)!)
            #expect(isAllowed)
        }
    }

    @Test func unsafeRedirectsAreRefusedBeforeFoundationFollowsThem() async {
        let validator = RemoteMediaArtworkDestinationValidator()
        let safe = await RemoteMediaArtworkFetcher.shouldFollowRedirect(
            to: URLRequest(url: URL(string: "https://public.example/next.jpg")!),
            validator: validator
        )
        let localDestination = await RemoteMediaArtworkFetcher.shouldFollowRedirect(
            to: URLRequest(url: URL(string: "https://192.168.1.2/next.jpg")!),
            validator: validator
        )
        let insecureDestination = await RemoteMediaArtworkFetcher.shouldFollowRedirect(
            to: URLRequest(url: URL(string: "http://public.example/next.jpg")!),
            validator: validator
        )

        #expect(safe)
        #expect(localDestination)
        #expect(!insecureDestination)
    }

    /// The ledger is 6144 KB, so the ceiling is part of the contract rather than a detail.
    @Test func theSizeCeilingIsBounded() {
        #expect(RemoteMediaArtworkFetcher.maximumBytes <= 2 * 1024 * 1024)
        #expect(RemoteMediaArtworkFetcher.timeout <= 5)
    }

    /// Refused and unreachable sources are distinct outcomes for callers that want to explain a
    /// missing image without retrying an unsafe request.
    @Test func aRefusalSaysWhy() async {
        let refused = await RemoteMediaArtworkFetcher.fetch(
            from: URL(string: "https://127.0.0.1/art.jpg")!
        )
        #expect(refused.data == nil)
        #expect(refused.reason == "refused source")
        #expect(refused.status == nil)
    }

    @Test func anOversizedBodyStopsAsSoonAsTheLimitIsExceeded() async throws {
        let result = try await RemoteMediaArtworkFetcher.boundedData(
            from: ByteSequence(remaining: 100),
            maximumBytes: 8
        )
        #expect(result == .tooLarge(byteCount: 9))
    }

    private struct ByteSequence: AsyncSequence, AsyncIteratorProtocol {
        typealias Element = UInt8

        var remaining: Int

        func makeAsyncIterator() -> ByteSequence { self }

        mutating func next() async -> UInt8? {
            guard remaining > 0 else { return nil }
            remaining -= 1
            return 0
        }
    }
}
