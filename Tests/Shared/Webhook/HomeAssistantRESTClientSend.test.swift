import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import SharedTesting
import Testing

/// `HomeAssistantRESTClient.send` end to end against OHHTTPStubs: URL building, the bearer token,
/// JSON bodies and status handling. Stubs are process-wide, so the suite serializes.
@Suite(.sharedState)
struct HomeAssistantRESTClientSendTests {
    private static let host = "a6-restclient.example.com"

    /// A fresh server (and so a fresh token manager) for each use: a 401 invalidates the token,
    /// and refreshing it would go to the network.
    private var server: Server {
        Server.fake { info in
            info.connection.set(address: URL(string: "http://\(Self.host):8123")!, for: .external)
        }
    }

    private func withStub(
        _ path: String,
        _ response: @escaping (URLRequest) -> HTTPStubsResponse,
        _ body: () async throws -> Void
    ) async rethrows {
        let descriptor = stub(condition: isHost(Self.host) && isPath(path), response: response)
        defer { HTTPStubs.removeStub(descriptor) }
        try await body()
    }

    @Test func getReturnsTheBodyWithTheBearerToken() async throws {
        var authorization: String?
        try await withStub("/api/states/light.kitchen", { request in
            authorization = request.value(forHTTPHeaderField: "Authorization")
            return HTTPStubsResponse(jsonObject: ["state": "on"], statusCode: 200, headers: nil)
        }) {
            let json = try await HomeAssistantRESTClient.sendForJSON(server: server, path: ["states", "light.kitchen"])
            #expect((json as? [String: Any])?["state"] as? String == "on")
        }
        #expect(authorization == "Bearer FakeAccessToken")
    }

    @Test func postSendsAJSONBodyAndQuery() async throws {
        var sentBody: [String: Any]?
        var sentQuery: String?
        try await withStub("/api/services/light/turn_on", { request in
            sentBody = request.ohhttpStubs_httpBody
                .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            sentQuery = request.url?.query
            return HTTPStubsResponse(data: Data("[]".utf8), statusCode: 200, headers: nil)
        }) {
            let data = try await HomeAssistantRESTClient.send(
                server: server,
                method: .post,
                path: ["services", "light", "turn_on"],
                query: [URLQueryItem(name: "return_response", value: nil)],
                body: ["entity_id": "light.kitchen"]
            )
            #expect(data == Data("[]".utf8))
        }
        #expect(sentBody?["entity_id"] as? String == "light.kitchen")
        #expect(sentQuery == "return_response")
    }

    @Test func unacceptableStatusesThrowWithTheBody() async {
        await withStub("/api/states", { _ in
            HTTPStubsResponse(data: Data("nope".utf8), statusCode: 401, headers: nil)
        }) {
            await #expect(throws: HomeAssistantRESTError.self) {
                try await HomeAssistantRESTClient.send(server: server, path: ["states"])
            }
        }
        await withStub("/api/states", { _ in
            HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
        }) {
            await #expect(throws: HomeAssistantRESTError.self) {
                try await HomeAssistantRESTClient.sendForJSON(server: server, path: ["states"])
            }
        }
    }

    @Test func aServerWithoutAnyURLFailsUpFront() async {
        let unreachable = Server.fake { info in
            info.connection.set(address: nil, for: .external)
            info.connection.set(address: nil, for: .internal)
        }
        await #expect(throws: (any Error).self) {
            try await HomeAssistantRESTClient.send(server: unreachable, path: ["states"])
        }
    }
}
