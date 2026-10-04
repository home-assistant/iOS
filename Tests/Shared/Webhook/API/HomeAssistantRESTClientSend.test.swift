import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import XCTest

final class HomeAssistantRESTClientSendTests: XCTestCase {
    private var descriptors = [HTTPStubsDescriptor]()
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!

    override func setUp() {
        super.setUp()
        previousCachedApis = Current.cachedApis
        server = .fake(update: { info in
            info.connection.set(address: URL(string: "http://rest-client.example:8123"), for: .external)
        })
    }

    override func tearDown() {
        descriptors.forEach { HTTPStubs.removeStub($0) }
        descriptors = []
        Current.cachedApis = previousCachedApis
        server = nil
        super.tearDown()
    }

    /// Answers requests to `path` on the test host and records what was sent.
    private func stubPath(
        _ path: String,
        statusCode: Int32 = 200,
        body: Data = Data(),
        record: @escaping (URLRequest) -> Void = { _ in }
    ) {
        descriptors.append(stub(
            condition: { $0.url?.host == "rest-client.example" && $0.url?.path == path },
            response: { request in
                record(request)
                return HTTPStubsResponse(data: body, statusCode: statusCode, headers: [:])
            }
        ))
    }

    func testSendReturnsTheBodyAndAuthenticates() async throws {
        var sent: URLRequest?
        stubPath("/api/states/light.kitchen", body: Data("payload".utf8), record: { sent = $0 })

        let data = try await HomeAssistantRESTClient.send(server: server, path: ["states", "light.kitchen"])

        XCTAssertEqual(String(data: data, encoding: .utf8), "payload")
        let request = try XCTUnwrap(sent)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer FakeAccessToken")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), HomeAssistantAPI.userAgent)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    func testSendPostsAJSONBodyWithQuery() async throws {
        var sent: URLRequest?
        stubPath("/api/services/light/turn_on", record: { sent = $0 })

        _ = try await HomeAssistantRESTClient.send(
            server: server,
            method: .post,
            path: ["services", "light", "turn_on"],
            query: [URLQueryItem(name: "return_response", value: nil)],
            body: ["entity_id": "light.kitchen"]
        )

        let request = try XCTUnwrap(sent)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.url?.query, "return_response")
        let body = try XCTUnwrap(request.ohhttpStubs_httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json, ["entity_id": "light.kitchen"])
    }

    func testSendThrowsForUnacceptableStatusesKeepingTheBody() async {
        stubPath("/api/template", statusCode: 400, body: Data("bad template".utf8))

        do {
            _ = try await HomeAssistantRESTClient.send(server: server, method: .post, path: ["template"])
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(
                error as? HomeAssistantRESTError,
                .unacceptableStatus(code: 400, body: "bad template")
            )
        }
    }

    func testUnauthorizedResponseInvalidatesTheToken() async {
        stubPath("/api/states", statusCode: 401)
        XCTAssertNotEqual(server.info.token.expiration, .distantPast)

        do {
            _ = try await HomeAssistantRESTClient.send(server: server, path: ["states"])
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? HomeAssistantRESTError, .unacceptableStatus(code: 401, body: ""))
        }

        XCTAssertEqual(server.info.token.expiration, .distantPast)
    }

    func testSendWithoutAnActiveURLThrows() async {
        let server = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })

        do {
            _ = try await HomeAssistantRESTClient.send(server: server, path: ["states"])
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is ServerConnectionError, "\(error)")
        }
    }

    func testSendForJSONDecodesTheBody() async throws {
        stubPath("/api/config", body: Data(#"{"version": "2026.1.0", "components": ["light"]}"#.utf8))

        let json = try await HomeAssistantRESTClient.sendForJSON(server: server, path: ["config"])

        let dictionary = try XCTUnwrap(json as? [String: Any])
        XCTAssertEqual(dictionary["version"] as? String, "2026.1.0")
        XCTAssertEqual(dictionary["components"] as? [String], ["light"])
    }

    func testSendForJSONAcceptsFragments() async throws {
        stubPath("/api/template", body: Data("42".utf8))

        let json = try await HomeAssistantRESTClient.sendForJSON(server: server, method: .post, path: ["template"])

        XCTAssertEqual(json as? Int, 42)
    }

    func testSendForJSONRejectsInvalidJSON() async {
        stubPath("/api/template", body: Data("not json".utf8))

        do {
            _ = try await HomeAssistantRESTClient.sendForJSON(server: server, path: ["template"])
            XCTFail("expected an error")
        } catch {
            XCTAssertFalse(error is HomeAssistantRESTError)
        }
    }
}
