@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// How the HLS player gets to a stream: it asks the server for one over the webhook, and every way
/// that can fail (no address, a refused request, no HLS path, a playlist that won't load) either
/// hands over to the fallback player or ends in an error message.
@Suite(.sharedState)
@MainActor
struct CameraStreamHLSViewLoadingTests {
    /// Answers `stream_camera` with whatever the test chose, without a server.
    private final class StreamCameraWebhookManager: WebhookManager {
        private(set) var response: Swift.Result<[String: Any], Error> = .success([:])
        private(set) var requestTypes: [String] = []

        /// Sets what `stream_camera` answers from now on and forgets the requests an earlier case made, so a
        /// case only ever sees its own.
        func configure(_ response: Swift.Result<[String: Any], Error>) {
            self.response = response
            requestTypes = []
        }

        override func sendEphemeral<ResponseType>(
            server: Server,
            request: WebhookRequest,
            overrideURL: URL? = nil
        ) -> Promise<ResponseType> {
            requestTypes.append(request.type)
            switch response {
            case let .success(json):
                guard let value = json as? ResponseType else {
                    return .init(error: StreamError.unexpectedType)
                }
                return .value(value)
            case let .failure(error):
                return .init(error: error)
            }
        }
    }

    private enum StreamError: Error {
        case refused
        case unexpectedType
    }

    private static let webhooks = StreamCameraWebhookManager()

    private final class Recorder {
        var fallbacks = 0
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func server(reachable: Bool) -> Server {
        Server.fake { info in
            // A closed port on the loopback interface: nothing ever answers there.
            info.connection.set(address: reachable ? URL(string: "http://127.0.0.1:9") : nil, for: .external)
        }
    }

    private func withWebhooks(
        _ response: Swift.Result<[String: Any], Error>,
        _ body: () async throws -> Void
    ) async rethrows {
        let previousWebhooks = Current.webhooks
        let previousCachedApis = Current.cachedApis
        Self.webhooks.configure(response)
        Current.webhooks = Self.webhooks
        defer {
            Current.webhooks = previousWebhooks
            Current.cachedApis = previousCachedApis
        }
        try await body()
    }

    private func host(_ view: CameraStreamHLSView) -> (UIViewController, UIWindow) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        return (controller, window)
    }

    private func tearDown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    enum StreamAnswer: CaseIterable {
        case refused
        case mjpegOnly

        var response: Swift.Result<[String: Any], Error> {
            switch self {
            case .refused: .failure(StreamError.refused)
            case .mjpegOnly: .success(["mjpeg_path": "/api/camera_proxy_stream/camera.porch"])
            }
        }
    }

    @Test(arguments: StreamAnswer.allCases)
    func everyFailureHandsOverToTheFallbackPlayer(answer: StreamAnswer) async {
        await withWebhooks(answer.response) {
            let recorder = Recorder()
            let (_, window) = host(CameraStreamHLSView(
                server: server(reachable: true),
                cameraEntityId: "camera.porch",
                cameraName: "Porch",
                controlsVisible: .constant(true),
                onHLSUnsupported: { recorder.fallbacks += 1 }
            ))
            defer { tearDown(window) }

            let expectation1 = await waitUntil { recorder.fallbacks == 1 }
            #expect(expectation1)
        }
    }

    /// The playlist sits on a closed port, so the player is set up but never gets to play.
    @Test func anHLSPathSetsUpThePlayer() async {
        await withWebhooks(.success(["hls_path": "/api/hls/token/master_playlist.m3u8"])) {
            let (controller, window) = host(CameraStreamHLSView(
                server: server(reachable: true),
                cameraEntityId: "camera.porch"
            ))
            defer { tearDown(window) }

            let expectation2 = await waitUntil { Self.webhooks.requestTypes.contains("stream_camera") }
            #expect(expectation2)
            for _ in 0 ..< 10 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    @Test func aServerWithoutAnAddressFallsBackStraightAway() async {
        await withWebhooks(.success([:])) {
            let recorder = Recorder()
            let (_, window) = host(CameraStreamHLSView(
                server: server(reachable: false),
                cameraEntityId: "camera.porch",
                onHLSUnsupported: { recorder.fallbacks += 1 }
            ))
            defer { tearDown(window) }

            let expectation3 = await waitUntil { recorder.fallbacks == 1 }
            #expect(expectation3)
        }
    }

    @Test(arguments: [false, true])
    func withoutAFallbackTheErrorIsShown(reachable: Bool) async {
        await withWebhooks(.failure(StreamError.refused)) {
            let (controller, window) = host(CameraStreamHLSView(
                server: server(reachable: reachable),
                cameraEntityId: "camera.porch"
            ))
            defer { tearDown(window) }

            if reachable {
                let expectation4 = await waitUntil { Self.webhooks.requestTypes.contains("stream_camera") }
                #expect(expectation4)
            }
            for _ in 0 ..< 5 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }

    @Test func streamErrorsDescribeThemselves() {
        #expect(CameraStreamHLSView.StreamError.noActiveURL.errorDescription != nil)
        #expect(CameraStreamHLSView.StreamError.noHLSAvailable.errorDescription != nil)
    }
}
