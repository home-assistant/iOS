import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// `MJPEGStreamer` reading a stubbed `camera_proxy_stream`. OHHTTPStubs is process-wide, so the suite
/// serializes with other shared-state tests.
@Suite(.sharedState)
struct MJPEGStreamerStreamingTests {
    private static let host = "a6-mjpeg.example.com"

    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [(UIImage?, Error?)] = []
        func append(_ value: (UIImage?, Error?)) { lock.lock(); storage.append(value); lock.unlock() }
        var all: [(UIImage?, Error?)] { lock.lock(); defer { lock.unlock() }; return storage }
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func expectEventually(
        _ condition: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        let met = await waitUntil(condition)
        #expect(met, sourceLocation: sourceLocation)
    }

    private func makeStreamer() -> MJPEGStreamer {
        let server = Server.fake { info in
            info.connection.set(address: URL(string: "http://\(Self.host):8123")!, for: .external)
        }
        return HomeAssistantAPI(server: server).VideoStreamer()
    }

    private var jpeg: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    @Test func framesBecomeImagesAndTheEndOfTheStreamIsReported() async throws {
        let frame = jpeg
        let descriptor = stub(condition: isHost(Self.host) && isPath("/api/camera_proxy_stream/camera.door")) { _ in
            HTTPStubsResponse(data: frame, statusCode: 200, headers: ["Content-Type": "image/jpeg"])
        }
        defer { HTTPStubs.removeStub(descriptor) }

        let streamer = makeStreamer()
        let results = Results()
        let url = try #require(URL(string: "http://\(Self.host):8123/api/camera_proxy_stream/camera.door"))
        streamer.streamImages(fromURL: url) { image, error in results.append((image, error)) }
        #expect(streamer.isActive)

        // The stub delivers one body and ends, which surfaces as the end of the stream.
        await expectEventually { results.all.contains { $0.1 != nil } }

        // A new part boundary turns what was buffered into an image.
        let task = try #require(streamer.request?.task)
        NotificationCenter.default.post(
            name: MJPEGStreamerSessionDelegate.didReceiveResponse,
            object: streamer.manager.delegate,
            userInfo: [MJPEGStreamerSessionDelegate.taskUserInfoKey: task]
        )
        await expectEventually { results.all.contains { $0.0 != nil } }

        streamer.cancel()
        #expect(!streamer.isActive)
    }

    @Test func failingStreamsReportTheirError() async throws {
        let descriptor = stub(condition: isHost(Self.host) && isPath("/api/camera_proxy_stream/camera.gone")) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 404, headers: nil)
        }
        defer { HTTPStubs.removeStub(descriptor) }

        let streamer = makeStreamer()
        let results = Results()
        let url = try #require(URL(string: "http://\(Self.host):8123/api/camera_proxy_stream/camera.gone"))
        streamer.streamImages(fromURL: url) { image, error in results.append((image, error)) }
        await expectEventually { !results.all.isEmpty }
        #expect(results.all.first?.0 == nil)
        #expect(results.all.first?.1 != nil)
        streamer.cancel()
    }

    @Test func eventsDescribeThemselves() {
        #expect(MJPEGEvent.data(Data([1, 2])).description == "data(2)")
        #expect(MJPEGEvent.endOfResponse.description == "endOfResponse")
        #expect(MJPEGEvent.endOfStream(nil).description == "endOfStream(nil)")
    }
}
