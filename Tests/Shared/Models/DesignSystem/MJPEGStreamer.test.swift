import Alamofire
import Foundation
@testable import Shared
import UIKit
import XCTest

/// Streams from a `URLProtocol` stub instead of the network, so the whole streamer runs — request,
/// validation, buffering and the response-boundary notification — without a server.
final class MJPEGStreamerTests: XCTestCase {
    private var observers: [NSObjectProtocol] = []

    override func tearDown() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        super.tearDown()
    }

    private func makeStreamer() -> MJPEGStreamer {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MJPEGStreamerStubProtocol.self]
        let delegate = MJPEGStreamerSessionDelegate(server: Server.fake())
        return MJPEGStreamer(manager: Alamofire.Session(configuration: configuration, delegate: delegate))
    }

    func testEventDescriptions() {
        XCTAssertEqual(MJPEGEvent.data(Data([1, 2, 3])).description, "data(3)")
        XCTAssertEqual(MJPEGEvent.endOfResponse.description, "endOfResponse")
        XCTAssertEqual(MJPEGEvent.endOfStream(nil).description, "endOfStream(nil)")
        XCTAssertTrue(
            MJPEGEvent.endOfStream(AFError.explicitlyCancelled).description.hasPrefix("endOfStream(Optional(")
        )
    }

    func testIsInactiveUntilStreamingAndAfterCancelling() {
        let streamer = makeStreamer()
        XCTAssertFalse(streamer.isActive)

        streamer.streamImages(fromURL: MJPEGStreamerStubProtocol.hangingURL) { _, _ in }
        XCTAssertTrue(streamer.isActive)

        streamer.cancel()
        XCTAssertFalse(streamer.isActive)
    }

    func testFailedResponseEndsTheStreamWithAnError() {
        let streamer = makeStreamer()
        let ended = expectation(description: "stream ended")
        var receivedImage: UIImage?
        var receivedError: Error?

        streamer.streamImages(fromURL: MJPEGStreamerStubProtocol.notFoundURL) { image, error in
            receivedImage = image
            receivedError = error
            ended.fulfill()
        }

        wait(for: [ended], timeout: 10)
        XCTAssertNil(receivedImage)
        XCTAssertNotNil(receivedError)
        streamer.cancel()
    }

    func testFrameIsDeliveredAtTheResponseBoundary() throws {
        let streamer = makeStreamer()
        let responseTask = ResponseTaskBox()
        observers.append(NotificationCenter.default.addObserver(
            forName: MJPEGStreamerSessionDelegate.didReceiveResponse,
            object: streamer.manager.delegate,
            queue: nil
        ) { note in
            responseTask.set(note.userInfo?[MJPEGStreamerSessionDelegate.taskUserInfoKey] as? URLSessionTask)
        })

        let ended = expectation(description: "stream ended")
        let frame = expectation(description: "frame delivered")
        var endError: Error?
        var frameImage: UIImage?

        streamer.streamImages(fromURL: MJPEGStreamerStubProtocol.frameURL) { image, error in
            if let image {
                frameImage = image
                frame.fulfill()
            } else {
                endError = error
                ended.fulfill()
            }
        }

        // The stub answers with one JPEG and then closes the connection without a new part, so the
        // streamer reports the end of the stream while still holding the frame.
        wait(for: [ended], timeout: 10)
        XCTAssertTrue(endError is MJPEGStreamer.MJPEGError)

        let streamTask = try XCTUnwrap(responseTask.get())

        // Announcing the next part's response is what turns the buffered bytes into an image.
        NotificationCenter.default.post(
            name: MJPEGStreamerSessionDelegate.didReceiveResponse,
            object: streamer.manager.delegate,
            userInfo: [MJPEGStreamerSessionDelegate.taskUserInfoKey: streamTask]
        )

        wait(for: [frame], timeout: 10)
        let image = try XCTUnwrap(frameImage)
        XCTAssertEqual(image.size.width, MJPEGStreamerStubProtocol.frameSize.width, accuracy: 0.5)
        XCTAssertEqual(image.size.height, MJPEGStreamerStubProtocol.frameSize.height, accuracy: 0.5)
        streamer.cancel()
    }

    /// Holds the task the session announced, written from the session's delegate queue.
    private final class ResponseTaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionTask?

        func set(_ task: URLSessionTask?) {
            lock.lock()
            defer { lock.unlock() }
            self.task = task
        }

        func get() -> URLSessionTask? {
            lock.lock()
            defer { lock.unlock() }
            return task
        }
    }
}

/// Answers by URL path, so the stub holds no mutable state shared between tests.
private final class MJPEGStreamerStubProtocol: URLProtocol {
    static let frameURL = URL(string: "https://mjpeg.stub/frame")!
    static let notFoundURL = URL(string: "https://mjpeg.stub/missing")!
    static let hangingURL = URL(string: "https://mjpeg.stub/hang")!
    static let frameSize = CGSize(width: 4, height: 3)

    static let frameData: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: frameSize, format: format).jpegData(withCompressionQuality: 1) { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: frameSize))
        }
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client, let url = request.url else { return }

        switch url.path {
        case Self.frameURL.path:
            respond(client: client, url: url, statusCode: 200, body: Self.frameData)
        case Self.notFoundURL.path:
            respond(client: client, url: url, statusCode: 404, body: Data())
        default:
            // Never answers, so the request stays in flight until it is cancelled.
            break
        }
    }

    override func stopLoading() {}

    private func respond(client: URLProtocolClient, url: URL, statusCode: Int, body: Data) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/jpeg"]
        ) else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !body.isEmpty {
            client.urlProtocol(self, didLoad: body)
        }
        client.urlProtocolDidFinishLoading(self)
    }
}
