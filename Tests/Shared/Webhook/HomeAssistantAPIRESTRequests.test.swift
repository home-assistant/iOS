import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// The Alamofire-backed REST helpers of `HomeAssistantAPI`, answered by OHHTTPStubs. Stubs are
/// process-wide, so the suite serializes with other shared-state tests and removes its own stubs.
@Suite(.sharedState)
struct HomeAssistantAPIRESTRequestsTests {
    private static let host = "a6-rest.example.com"

    private func makeAPI(version: Version? = nil) -> HomeAssistantAPI {
        let server = Server.fake { info in
            info.connection.set(address: URL(string: "http://\(Self.host):8123")!, for: .external)
            if let version {
                info.version = version
            }
        }
        return HomeAssistantAPI(server: server)
    }

    private func withStub(
        path: String,
        _ response: @escaping (URLRequest) -> HTTPStubsResponse,
        _ body: () async throws -> Void
    ) async rethrows {
        let descriptor = stub(condition: isHost(Self.host) && isPath(path), response: response)
        defer { HTTPStubs.removeStub(descriptor) }
        try await body()
    }

    private func json(_ object: Any, status: Int32 = 200) -> HTTPStubsResponse {
        HTTPStubsResponse(jsonObject: object, statusCode: status, headers: ["Content-Type": "application/json"])
    }

    @Test func stringRequestReturnsTheBodyOrTheFailure() async throws {
        let api = makeAPI()
        try await withStub(path: "/api/text", { _ in
            HTTPStubsResponse(data: Data("hello".utf8), statusCode: 200, headers: ["Content-Type": "text/plain"])
        }) {
            let promise: Promise<String> = api.request(path: "text", callingFunctionName: "test")
            let body = try await promise.asyncValue()
            #expect(body == "hello")
        }
        await withStub(path: "/api/text", { _ in HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil) }) {
            let promise: Promise<String> = api.request(path: "text", callingFunctionName: "test", method: .post)
            await #expect(throws: (any Error).self) { try await promise.asyncValue() }
        }
    }

    @Test func mappableRequestsDecodeObjectsAndArrays() async throws {
        let api = makeAPI()
        try await withStub(path: "/api/camera", { _ in json(["hls_path": "/hls", "mjpeg_path": "/mjpeg"]) }) {
            let promise: Promise<StreamCameraResponse> = api.request(path: "camera", callingFunctionName: "test")
            let response = try await promise.asyncValue()
            #expect(response.hlsPath == "/hls")
        }
        try await withStub(path: "/api/cameras", { _ in json([["hls_path": "/a"], ["mjpeg_path": "/b"]]) }) {
            let promise: Promise<[StreamCameraResponse]> = api.request(path: "cameras", callingFunctionName: "test")
            let responses = try await promise.asyncValue()
            #expect(responses.count == 2)
        }
    }

    @Test func immutableMappableRequestsDecodeOrReject() async throws {
        let api = makeAPI()
        try await withStub(path: "/api/action", { _ in json(["identifier": "OK", "category": "ALARM"]) }) {
            let immutable: Promise<HomeAssistantAPI.PushActionInfo> = api.requestImmutable(
                path: "action",
                callingFunctionName: "t"
            )
            let info = try await immutable.asyncValue()
            #expect(info.identifier == "OK")
            #expect(info.category == "ALARM")
        }
        await withStub(path: "/api/action", { _ in json(["unexpected": true]) }) {
            let immutable: Promise<HomeAssistantAPI.PushActionInfo> = api.requestImmutable(
                path: "action",
                callingFunctionName: "t"
            )
            await #expect(throws: (any Error).self) { try await immutable.asyncValue() }
        }
    }

    @Test func mobileAppConfigReadsThePushCategoriesOrDefaults() async throws {
        let api = makeAPI(version: Version(major: 2024, minor: 1, patch: 0))
        try await withStub(path: "/api/ios/config", { _ in json(["push": ["categories": []]]) }) {
            _ = try await api.GetMobileAppConfig().asyncValue()
        }
        try await withStub(path: "/api/ios/config", { _ in json([:], status: 404) }) {
            let config = try await api.GetMobileAppConfig().asyncValue()
            #expect(config.push.categories.isEmpty)
        }
        await withStub(path: "/api/ios/config", { _ in json([:], status: 500) }) {
            await #expect(throws: (any Error).self) { try await api.GetMobileAppConfig().asyncValue() }
        }

        let legacy = makeAPI(version: Version(major: 0, minor: 110, patch: 0))
        try await withStub(path: "/api/ios/push", { _ in json(["categories": []]) }) {
            _ = try await legacy.GetMobileAppConfig().asyncValue()
        }
    }

    @Test func cameraSnapshotDecodesTheImage() async throws {
        let api = makeAPI()
        let png = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        try await withStub(path: "/api/camera_proxy/camera.door", { _ in
            HTTPStubsResponse(data: png, statusCode: 200, headers: ["Content-Type": "image/png"])
        }) {
            let image = try await api.getCameraSnapshot(cameraEntityID: "camera.door").asyncValue()
            #expect(image.size.width > 0)
        }
        await withStub(path: "/api/camera_proxy/camera.door", { _ in
            HTTPStubsResponse(data: Data("not an image".utf8), statusCode: 200, headers: nil)
        }) {
            await #expect(throws: (any Error).self) {
                try await api.getCameraSnapshot(cameraEntityID: "camera.door").asyncValue()
            }
        }
        await withStub(path: "/api/camera_proxy/camera.door", { _ in
            HTTPStubsResponse(data: Data(), statusCode: 404, headers: nil)
        }) {
            await #expect(throws: (any Error).self) {
                try await api.getCameraSnapshot(cameraEntityID: "camera.door").asyncValue()
            }
        }
    }

    @Test func downloadsLandInATemporaryFile() async throws {
        let api = makeAPI()
        try await withStub(path: "/media/clip.mp4", { _ in
            HTTPStubsResponse(data: Data([1, 2, 3]), statusCode: 200, headers: nil)
        }) {
            let relative = try #require(URL(string: "media/clip.mp4"))
            let url = try await api.DownloadDataAt(url: relative, needsAuth: true).asyncValue()
            defer { try? FileManager.default.removeItem(at: url) }
            let downloaded = try Data(contentsOf: url)
            #expect(downloaded == Data([1, 2, 3]))
            #expect(url.pathExtension == "mp4")

            let absolute = try #require(URL(string: "http://\(Self.host):8123/media/clip.mp4"))
            let second = try await api.DownloadDataAt(url: absolute, needsAuth: false).asyncValue()
            try? FileManager.default.removeItem(at: second)
        }
        await withStub(
            path: "/media/missing.mp4",
            { _ in HTTPStubsResponse(data: Data(), statusCode: 404, headers: nil) }
        ) {
            let missing = URL(string: "http://\(Self.host):8123/media/missing.mp4")!
            await #expect(throws: (any Error).self) {
                try await api.DownloadDataAt(url: missing, needsAuth: true).asyncValue()
            }
        }
        #expect(api.temporaryDownloadFileURL()?.pathExtension == "")
    }
}
