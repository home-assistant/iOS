import Alamofire
import Foundation
import HAKit
import HAKit_Mocks
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import XCTest

final class HomeAssistantAPIRESTTests: XCTestCase {
    private var webhookManager: FakeWebhookManager!
    private var previousWebhookManager: WebhookManager!
    private var previousIsAppExtension: Bool!

    override func setUp() {
        super.setUp()
        previousWebhookManager = Current.webhooks
        previousIsAppExtension = Current.isAppExtension
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager
        Current.isAppExtension = false
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        Current.webhooks = previousWebhookManager
        Current.isAppExtension = previousIsAppExtension
        super.tearDown()
    }

    private func makeAPI(update: (inout ServerInfo) -> Void = { _ in }) -> HomeAssistantAPI {
        let api = HomeAssistantAPI(server: .fake(update: { info in
            info.setSetting(value: "Test Phone", for: .overrideDeviceName)
            update(&info)
        }))
        api.connection = HAMockConnection()
        return api
    }

    private func makeAPIWithoutURL() -> HomeAssistantAPI {
        makeAPI { info in
            info.connection.set(address: nil, for: .external)
        }
    }

    private func stubPath(_ path: String, json: Any, statusCode: Int32 = 200) {
        stub(condition: { $0.url?.path == path }, response: { _ in
            HTTPStubsResponse(jsonObject: json, statusCode: statusCode, headers: ["Content-Type": "application/json"])
        })
    }

    private func stubPath(_ path: String, data: Data, statusCode: Int32 = 200) {
        stub(condition: { $0.url?.path == path }, response: { _ in
            HTTPStubsResponse(data: data, statusCode: statusCode, headers: [:])
        })
    }

    private func assertNoActiveURL(_ promise: Promise<some Any>, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try hang(promise), file: file, line: line) { error in
            XCTAssertTrue(error is ServerConnectionError, "\(error)", file: file, line: line)
        }
    }

    private func assertStatusCode(
        _ statusCode: Int,
        from promise: Promise<some Any>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try hang(promise), file: file, line: line) { error in
            guard case let AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: code)) = error else {
                XCTFail("unexpected error \(error)", file: file, line: line)
                return
            }
            XCTAssertEqual(code, statusCode, file: file, line: line)
        }
    }

    // MARK: - Generic request helpers

    func testStringRequestReturnsTheBody() throws {
        let api = makeAPI()
        stubPath("/api/some/text", data: Data("hello there".utf8))

        let promise: Promise<String> = api.request(path: "some/text", callingFunctionName: #function)

        XCTAssertEqual(try hang(promise), "hello there")
    }

    func testStringRequestRejectsHTTPErrors() {
        let api = makeAPI()
        stubPath("/api/some/text", data: Data(), statusCode: 404)

        let promise: Promise<String> = api.request(path: "some/text", callingFunctionName: #function)

        assertStatusCode(404, from: promise)
    }

    func testStringRequestWithoutActiveURL() {
        let api = makeAPIWithoutURL()

        let promise: Promise<String> = api.request(path: "some/text", callingFunctionName: #function)

        assertNoActiveURL(promise)
    }

    func testImmutableMappableRequest() throws {
        let api = makeAPI()
        stubPath("/api/ios/config", json: ["push": ["categories": []]])

        let promise: Promise<MobileAppConfig> = api.request(path: "ios/config", callingFunctionName: #function)

        XCTAssertTrue(try hang(promise).push.categories.isEmpty)
    }

    func testImmutableMappableRequestWithoutActiveURL() {
        let api = makeAPIWithoutURL()

        let promise: Promise<MobileAppConfig> = api.request(path: "ios/config", callingFunctionName: #function)

        assertNoActiveURL(promise)
    }

    // MARK: - Logbook

    func testGetLogbookMapsEntries() throws {
        let api = makeAPI()
        stubPath("/api/logbook", json: [
            [
                "entity_id": "light.kitchen",
                "when": "2026-01-02T10:00:00.000+0000",
                "domain": "light",
                "message": "turned on",
                "name": "Kitchen",
            ],
        ])

        let entries = try hang(api.GetLogbook())

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.entityId, "light.kitchen")
        XCTAssertEqual(entries.first?.domain, "light")
        XCTAssertEqual(entries.first?.message, "turned on")
        XCTAssertEqual(entries.first?.name, "Kitchen")
        XCTAssertEqual(entries.first?.when, Date(timeIntervalSince1970: 1_767_348_000))
    }

    func testGetLogbookRejectsHTTPErrors() {
        let api = makeAPI()
        stubPath("/api/logbook", json: [String: Any](), statusCode: 404)

        assertStatusCode(404, from: api.GetLogbook())
    }

    func testGetLogbookWithoutActiveURL() {
        assertNoActiveURL(makeAPIWithoutURL().GetLogbook())
    }

    // MARK: - Registration

    func testRegisterStoresTheNewWebhook() throws {
        let api = makeAPI()
        var body: Data?
        stub(condition: { $0.url?.path == "/api/mobile_app/registrations" }, response: { request in
            body = request.ohhttpStubs_httpBody
            return HTTPStubsResponse(jsonObject: [
                "webhook_id": "registered-webhook",
                "secret": "registered-secret",
                "cloudhook_url": "https://hooks.nabu.casa/registered",
                "remote_ui_url": "https://abc.ui.nabu.casa",
            ], statusCode: 201, headers: ["Content-Type": "application/json"])
        })

        try hang(api.register())

        let connection = api.server.info.connection
        XCTAssertEqual(connection.webhookID, "registered-webhook")
        XCTAssertEqual(connection.webhookSecret, "registered-secret")
        XCTAssertEqual(connection.cloudhookURL, URL(string: "https://hooks.nabu.casa/registered"))
        XCTAssertEqual(api.server.info.setting(for: .registeredDeviceName), "Test Phone")

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(body)) as? [String: Any]
        )
        XCTAssertEqual(json["app_id"] as? String, AppConstants.BundleID)
        XCTAssertEqual(json["app_version"] as? String, HomeAssistantAPI.clientVersionDescription)
        XCTAssertEqual(json["device_name"] as? String, "Test Phone")
        XCTAssertEqual(json["manufacturer"] as? String, "Apple")
        XCTAssertEqual(json["supports_encryption"] as? Bool, true)
        XCTAssertNotNil(json["device_id"])
    }

    func testRegisterOnOldServerOmitsDeviceID() throws {
        let api = makeAPI { info in
            info.version = "0.100.0"
        }
        var body: Data?
        stub(condition: { $0.url?.path == "/api/mobile_app/registrations" }, response: { request in
            body = request.ohhttpStubs_httpBody
            return HTTPStubsResponse(
                jsonObject: ["webhook_id": "registered-webhook"],
                statusCode: 201,
                headers: ["Content-Type": "application/json"]
            )
        })

        try hang(api.register())

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(body)) as? [String: Any]
        )
        XCTAssertNil(json["device_id"])
        XCTAssertEqual(json["device_name"] as? String, "Test Phone")
    }

    func testRegisterReportsMissingMobileAppIntegration() {
        let api = makeAPI()
        stubPath("/api/mobile_app/registrations", json: [String: Any](), statusCode: 404)

        XCTAssertThrowsError(try hang(api.register())) { error in
            XCTAssertEqual(error as? HomeAssistantAPI.APIError, .mobileAppComponentNotLoaded)
        }
    }

    func testRegisterPassesOtherErrorsThrough() {
        let api = makeAPI()
        stubPath("/api/mobile_app/registrations", json: [String: Any](), statusCode: 403)

        assertStatusCode(403, from: api.register())
    }

    func testRegisterWithoutActiveURL() {
        assertNoActiveURL(makeAPIWithoutURL().register())
    }

    func testConnectRegistersAgainWhenTheIntegrationIsMissing() {
        let api = makeAPI()
        // An unmappable `update_registration` response means the integration was deleted.
        webhookManager.sendEphemeralHandler = { _, _ in "" }
        var registrationAttempts = 0
        stub(condition: { $0.url?.path == "/api/mobile_app/registrations" }, response: { _ in
            registrationAttempts += 1
            return HTTPStubsResponse(jsonObject: [String: Any](), statusCode: 404, headers: [:])
        })

        XCTAssertThrowsError(try hang(api.Connect(reason: .cold))) { error in
            XCTAssertEqual(error as? HomeAssistantAPI.APIError, .mobileAppComponentNotLoaded)
        }
        XCTAssertEqual(registrationAttempts, 1)
    }

    // MARK: - Mobile app config

    func testGetMobileAppConfigUsesConfigEndpoint() throws {
        let api = makeAPI()
        var requestedPaths = [String]()
        stub(condition: { $0.url?.path.hasPrefix("/api/ios/") == true }, response: { request in
            requestedPaths.append(request.url?.path ?? "")
            return HTTPStubsResponse(
                jsonObject: ["push": ["categories": []]],
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        })

        let config = try hang(api.GetMobileAppConfig())

        XCTAssertTrue(config.push.categories.isEmpty)
        XCTAssertEqual(requestedPaths, ["/api/ios/config"])
    }

    func testGetMobileAppConfigUsesPushEndpointOnOldServers() throws {
        let api = makeAPI { info in
            info.version = "0.110.0"
        }
        var requestedPaths = [String]()
        stub(condition: { $0.url?.path.hasPrefix("/api/ios/") == true }, response: { request in
            requestedPaths.append(request.url?.path ?? "")
            return HTTPStubsResponse(
                jsonObject: ["categories": []],
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        })

        let config = try hang(api.GetMobileAppConfig())

        XCTAssertTrue(config.push.categories.isEmpty)
        XCTAssertEqual(requestedPaths, ["/api/ios/push"])
    }

    func testGetMobileAppConfigTreatsMissingComponentAsEmpty() throws {
        let api = makeAPI()
        stubPath("/api/ios/config", json: [String: Any](), statusCode: 404)

        let config = try hang(api.GetMobileAppConfig())

        XCTAssertTrue(config.push.categories.isEmpty)
    }

    func testGetMobileAppConfigPassesOtherErrorsThrough() {
        let api = makeAPI()
        stubPath("/api/ios/config", json: [String: Any](), statusCode: 403)

        assertStatusCode(403, from: api.GetMobileAppConfig())
    }

    func testGetMobileAppConfigWithoutActiveURL() {
        assertNoActiveURL(makeAPIWithoutURL().GetMobileAppConfig())
    }

    // MARK: - Camera snapshot

    func testCameraSnapshotRejectsNonImageData() {
        let api = makeAPI()
        stubPath("/api/camera_proxy/camera.door", data: Data("not an image".utf8))

        XCTAssertThrowsError(try hang(api.getCameraSnapshot(cameraEntityID: "camera.door"))) { error in
            XCTAssertEqual(error as? HomeAssistantAPI.APIError, .invalidResponse)
        }
    }

    func testCameraSnapshotRejectsHTTPErrors() {
        let api = makeAPI()
        stubPath("/api/camera_proxy/camera.door", data: Data(), statusCode: 404)

        assertStatusCode(404, from: api.getCameraSnapshot(cameraEntityID: "camera.door"))
    }

    func testCameraSnapshotWithoutActiveURL() {
        assertNoActiveURL(makeAPIWithoutURL().getCameraSnapshot(cameraEntityID: "camera.door"))
    }

    // MARK: - Downloads

    func testDownloadPrependsTheServerURLToRelativePaths() throws {
        let api = makeAPI()
        let payload = Data("file contents".utf8)
        stubPath("/media/file.txt", data: payload)
        let relative = try XCTUnwrap(URL(string: "media/file.txt"))

        let fileURL = try hang(api.DownloadDataAt(url: relative, needsAuth: true))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertEqual(fileURL.pathExtension, "txt")
        XCTAssertEqual(try Data(contentsOf: fileURL), payload)
    }

    func testDownloadWithAuthNeedsAnActiveURL() throws {
        let relative = try XCTUnwrap(URL(string: "media/file.txt"))

        assertNoActiveURL(makeAPIWithoutURL().DownloadDataAt(url: relative, needsAuth: true))
    }
}
