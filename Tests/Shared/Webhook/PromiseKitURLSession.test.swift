import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// The vendored PromiseKit `URLSession` extension against OHHTTPStubs (process-wide, hence serialized).
@Suite(.sharedState)
struct PromiseKitURLSessionTests {
    private static let host = "a6-pmk.example.com"

    private func respond(_ status: Int32, body: String = "body") -> HTTPStubsDescriptor {
        stub(condition: isHost(Self.host)) { _ in
            HTTPStubsResponse(data: Data(body.utf8), statusCode: status, headers: nil)
        }
    }

    @Test func successfulResponsesPassValidation() async throws {
        let descriptor = respond(200, body: "ok")
        defer { HTTPStubs.removeStub(descriptor) }
        let url = try #require(URL(string: "https://\(Self.host)/ok"))

        let result = try await URLSession.shared.dataTask(.promise, with: url).validate().asyncValue()
        #expect(result.data == Data("ok".utf8))
        let viaRequest = try await URLSession.shared.dataTask(.promise, with: URLRequest(url: url)).asyncValue()
        #expect((viaRequest.response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test func badStatusesBecomeDescriptiveErrors() async throws {
        let url = try #require(URL(string: "https://\(Self.host)/fail"))
        for status: Int32 in [401, 500] {
            let descriptor = respond(status)
            defer { HTTPStubs.removeStub(descriptor) }
            do {
                _ = try await URLSession.shared.dataTask(.promise, with: url).validate().asyncValue()
                Issue.record("expected \(status) to fail validation")
            } catch let error as PMKHTTPError {
                #expect(error.errorDescription?.contains(url.absoluteString) == true)
                #expect(error.description.contains("\(status)"))
            }
        }
    }

    @Test func transportFailuresReject() async throws {
        let descriptor = stub(condition: isHost(Self.host)) { _ in
            HTTPStubsResponse(error: URLError(.notConnectedToInternet))
        }
        defer { HTTPStubs.removeStub(descriptor) }
        let url = try #require(URL(string: "https://\(Self.host)/offline"))
        await #expect(throws: (any Error).self) {
            try await URLSession.shared.dataTask(.promise, with: url).asyncValue()
        }
    }
}
