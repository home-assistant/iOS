import Foundation
@testable import Shared
import XCTest
import OHHTTPStubs
import ObjectMapper
import PromiseKit

class WebhookManagerTests: XCTestCase {
    private var manager: WebhookManager!
    private var api: FakeHassAPI!
    private var webhookURL: URL!

    override func setUp() {
        super.setUp()

        api = FakeHassAPI(
            connectionInfo: ConnectionInfo(
                externalURL: URL(string: "http://example.com"),
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "given_id",
                webhookSecret: nil,
                internalSSIDs: nil
            ), tokenInfo: TokenInfo(
                accessToken: "accessToken",
                refreshToken: "refreshToken",
                expiration: Date()
            )
        )

        webhookURL = api.connectionInfo.webhookURL

        Current.api = { [weak self] in self?.api }

        manager = WebhookManager()
    }

    override func tearDown() {
        super.tearDown()
        HTTPStubs.removeAllStubs()
    }

    func testBackgroundHandlingCallsCompletionHandler() {
        var didInvokeCompletion = false

        manager.handleBackground(for: WebhookManager.URLSessionIdentifier, completionHandler: {
            didInvokeCompletion = true
        })

        manager.urlSessionDidFinishEvents(forBackgroundURLSession: manager.backgroundUrlSession)

        let expectation = self.expectation(description: "run loop")
        DispatchQueue.main.async { expectation.fulfill() }

        wait(for: [expectation], timeout: 10)
        XCTAssertTrue(didInvokeCompletion)
    }

    func testSendingEphemeralFailsEntirely() {
        let expectedError = URLError(.timedOut)
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(error: expectedError)
        })

        XCTAssertThrowsError(try hang(manager.sendEphemeral(request: expectedRequest))) { error in
            XCTAssertEqual(error as? URLError, expectedError)
        }
    }

    func testSendingEphemeralFailsOnceThenSucceeds() {
        var shouldFail = true
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)

            if shouldFail {
                shouldFail = false
                return HTTPStubsResponse(error: URLError(.notConnectedToInternet))
            } else {
                return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: [:])
            }
        })

        XCTAssertNoThrow(try hang(manager.sendEphemeral(request: expectedRequest)))
        XCTAssertFalse(shouldFail, "aka it did a loop")
    }

    func testSendingEphemeralFailsOnceThenSucceedsWithAChangedURL() {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        let nextAPI = FakeHassAPI(
            connectionInfo: ConnectionInfo(
                externalURL: URL(string: "http://example.changed"),
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "given_id",
                webhookSecret: nil,
                internalSSIDs: nil
            ), tokenInfo: TokenInfo(
                accessToken: "accessToken",
                refreshToken: "refreshToken",
                expiration: Date()
            )
        )
        let nextAPIWebhookURL = nextAPI.connectionInfo.webhookURL

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)

            self.api = nextAPI

            return HTTPStubsResponse(error: URLError(.notConnectedToInternet))
        })

        stub(condition: { req in req.url == nextAPIWebhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: [:])
        })

        XCTAssertNoThrow(try hang(manager.sendEphemeral(request: expectedRequest)))
    }

    func testSendingEphemeralExpectingString() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(data: #""result""#.data(using: .utf8)!, statusCode: 200, headers: [:])
        })

        XCTAssertEqual(try hang(manager.sendEphemeral(request: expectedRequest)), "result")
    }

    func testSendingEphemeralExpectingStringButGettingObject() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(jsonObject: ["bob": "your_uncle"], statusCode: 200, headers: [:])
        })

        let promise: Promise<String> = manager.sendEphemeral(request: expectedRequest)
        XCTAssertThrowsError(try hang(promise)) { error in
            switch error as? WebhookManagerError {
            case .unexpectedType:
                break
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    struct ExampleMappable: Mappable, Equatable {
        var value: String?

        init?(map: Map) {}

        init(value: String) {
            self.value = value
        }

        mutating func mapping(map: Map) {
            value <- map["value"]
        }
    }

    func testSendingEphemeralExpectingMappableObject() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true, "etc": "yerp"])
        let expectedResponse = ExampleMappable(value: "this is a string, yeah")

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(
                jsonObject: Mapper<ExampleMappable>().toJSON(expectedResponse),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<ExampleMappable> = manager.sendEphemeral(request: expectedRequest)
        XCTAssertEqual(try hang(promise), expectedResponse)
    }

    func testSendingEphemeralExpectingMappableObjectButFailing() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true, "etc": "yerp"])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(
                data: Data(),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<ExampleMappable> = manager.sendEphemeral(request: expectedRequest)
        XCTAssertThrowsError(try hang(promise)) { error in
            switch error as? WebhookManagerError {
            case .unmappableValue:
                break
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testSendingEphemeralExpectingMappableArray() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true, "etc": "yerp"])
        let expectedResponse1 = ExampleMappable(value: "this is a string, yeah")
        let expectedResponse2 = ExampleMappable(value: "i to am a string")

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(
                jsonObject: Mapper<ExampleMappable>().toJSONArray([expectedResponse1, expectedResponse2]),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<[ExampleMappable]> = manager.sendEphemeral(request: expectedRequest)
        XCTAssertEqual(try hang(promise), [expectedResponse1, expectedResponse2])
    }

    func testSendingEphemeralExpectingMappableArrayButFailing() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true, "etc": "yerp"])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(
                data: Data(),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<[ExampleMappable]> = manager.sendEphemeral(request: expectedRequest)
        XCTAssertThrowsError(try hang(promise)) { error in
            switch error as? WebhookManagerError {
            case .unmappableValue:
                break
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }
}

private func XCTAssertEqualWebhookRequest(
    _ lhsData: Data?,
    _ rhs: WebhookRequest,
    file: StaticString = #file,
    line: UInt = #line
) {
    do {
        let mapper = Mapper<WebhookRequest>(context: WebhookRequestContext.server)
        let lhs = try mapper.map(JSONObject: try JSONSerialization.jsonObject(with: lhsData ?? Data(), options: []))
        XCTAssertEqualWebhookRequest(lhs, rhs, file: file, line: line)
    } catch {
        XCTFail("got error: \(error)", file: file, line: line)
    }
}

private func XCTAssertEqualWebhookRequest(
    _ lhs: WebhookRequest,
    _ rhs: WebhookRequest,
    file: StaticString = #file,
    line: UInt = #line
) {
    let mapper = Mapper<WebhookRequest>(context: WebhookRequestContext.server)

    func value(for request: WebhookRequest) throws -> String {
        var writeOptions: JSONSerialization.WritingOptions = [.prettyPrinted]

        if #available(iOS 11, *) {
            writeOptions.insert(.sortedKeys)
        }

        let json = mapper.toJSON(request)
        let data = try JSONSerialization.data(withJSONObject: json, options: writeOptions)
        return String(data: data, encoding: .utf8) ?? ""
    }

    XCTAssertEqual(try value(for: lhs), try value(for: rhs), file: file, line: line)
}

private class FakeHassAPI: HomeAssistantAPI {

}
