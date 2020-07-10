import Foundation
@testable import Shared
import XCTest
import OHHTTPStubs
import ObjectMapper
import PromiseKit

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
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

        ReplacingTestHandler.reset()
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

    func testUnbalancedBackgroundHandlingDoesntCrash() {
        // not the best test: this will crash the test execution if it fails
        manager.urlSessionDidFinishEvents(forBackgroundURLSession: manager.backgroundUrlSession)
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

    func testSendingUnregisteredIdentifierErrors() {
        let promise1 = manager.send(identifier: .init(rawValue: "unregistered"), request: .init(type: "test", data: ()))
        XCTAssertThrowsError(try hang(promise1)) { error in
            switch error as? WebhookManagerError {
            case .unregisteredIdentifier:
                break
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testSendingPersistentUnhandledFailsEntirely() {
        let expectedError = URLError(.timedOut)
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(error: expectedError)
        })

        XCTAssertThrowsError(try hang(manager.send(request: expectedRequest))) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
        }
    }

    func testSendingPersistentUnhandledSucceeds() {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
        })

        XCTAssertNoThrow(try hang(manager.send(request: expectedRequest)))
    }

    func testSendingPersistentWithExistingCallsBothPromises() throws {
        let request1 = WebhookRequest(type: "webhook_name", data: ["json": true])
        let request2 = WebhookRequest(type: "webhook_name", data: ["elephant": true])

        let request1Expectation = expectation(description: "request1")
        let request1Blocking = expectation(description: "request1-blocking")

        let identifier = WebhookResponseIdentifier(rawValue: "replacing")
        manager.register(responseHandler: ReplacingTestHandler.self, for: identifier)

        var pendingPromise1: Promise<Void>?
        var pendingPromise2: Promise<Void>?

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            // second one, the one we want to not be cancelled
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request2)
            return HTTPStubsResponse(jsonObject: ["result": 2], statusCode: 200, headers: nil)
        })

        var stub1: HTTPStubsDescriptor?
        stub1 = stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { [manager] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request1)
            HTTPStubs.removeStub(stub1!)

            // first one, the one we want to cancel
            pendingPromise2 = manager!.send(identifier: identifier, request: request2)
            request1Expectation.fulfill()

            self.wait(for: [request1Blocking], timeout: 100.0)
            return HTTPStubsResponse(jsonObject: ["result": 1], statusCode: 200, headers: nil)
        })

        pendingPromise1 = manager.send(identifier: identifier, request: request1)

        wait(for: [request1Expectation], timeout: 10.0)

        guard let promise1 = pendingPromise1, let promise2 = pendingPromise2 else {
            XCTFail("expected promises")
            return
        }

        XCTAssertNoThrow(try hang(promise1))
        XCTAssertNoThrow(try hang(promise2))

        request1Blocking.fulfill()

        XCTAssertEqual(ReplacingTestHandler.createdHandlers.count, 1)
        let request = try hang(ReplacingTestHandler.createdHandlers[0].request!)
        let result = try hang(ReplacingTestHandler.createdHandlers[0].result!)

        XCTAssertEqualWebhookRequest(request, request2)
        XCTAssertEqual((result as? [String: Any])?["result"] as? Int, 2)
    }

    func testSendingPersistentWithExistingCallsButNotReplacing() throws {
        let request1 = WebhookRequest(type: "webhook_name", data: ["json": true])
        let request2 = WebhookRequest(type: "webhook_name", data: ["elephant": true])

        let request1Expectation = expectation(description: "request1")
        let request1Blocking = expectation(description: "request1-blocking")

        let identifier = WebhookResponseIdentifier(rawValue: "replacing")
        manager.register(responseHandler: ReplacingTestHandler.self, for: identifier)
        ReplacingTestHandler.shouldReplace = false

        var pendingPromise1: Promise<Void>?
        var pendingPromise2: Promise<Void>?

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request2)
            DispatchQueue.main.async { request1Blocking.fulfill() }
            return HTTPStubsResponse(jsonObject: ["result": 2], statusCode: 200, headers: nil)
        })

        var stub1: HTTPStubsDescriptor?
        stub1 = stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { [manager] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request1)
            HTTPStubs.removeStub(stub1!)

            pendingPromise2 = manager!.send(identifier: identifier, request: request2)
            request1Expectation.fulfill()

            self.wait(for: [request1Blocking], timeout: 100.0)
            return HTTPStubsResponse(jsonObject: ["result": 1], statusCode: 200, headers: nil)
        })

        pendingPromise1 = manager.send(identifier: identifier, request: request1)

        wait(for: [request1Expectation], timeout: 10.0)

        guard let promise1 = pendingPromise1, let promise2 = pendingPromise2 else {
            XCTFail("expected promises")
            return
        }

        XCTAssertNoThrow(try hang(promise1))
        XCTAssertNoThrow(try hang(promise2))

        // stubs are handling whether the content was called
        XCTAssertEqual(ReplacingTestHandler.createdHandlers.count, 2)
    }

    func testSendPersistentDifferentIdentifiersDontInteract() {
        let identifier = WebhookResponseIdentifier(rawValue: "replacing")
        manager.register(responseHandler: ReplacingTestHandler.self, for: identifier)

        let request1 = WebhookRequest(type: "webhook_name", data: ["json": true])
        let request2 = WebhookRequest(type: "webhook_name", data: ["elephant": true])

        let networkSemaphore = DispatchSemaphore(value: 0)

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { _ in
            networkSemaphore.wait()
            return HTTPStubsResponse(jsonObject: ["result": true], statusCode: 200, headers: nil)
        })

        let promise1 = manager.send(identifier: .unhandled, request: request1)
        let promise2 = manager.send(identifier: identifier, request: request2)

        networkSemaphore.signal()
        networkSemaphore.signal()

        XCTAssertNoThrow(try hang(promise1))
        XCTAssertNoThrow(try hang(promise2))

        XCTAssertTrue(ReplacingTestHandler.shouldReplaceInvocations.isEmpty)
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

class ReplacingTestHandler: WebhookResponseHandler {
    static var returnedResult: WebhookResponseHandlerResult?
    static var shouldReplace: Bool = true

    static func reset() {
        returnedResult = nil
        shouldReplace = true
        createdHandlers = []
        shouldReplaceInvocations = []
    }

    static var createdHandlers = [ReplacingTestHandler]()
    required init(api: HomeAssistantAPI) {
        Self.createdHandlers.append(self)
    }

    static var shouldReplaceInvocations = [(current: WebhookRequest, proposed: WebhookRequest)]()

    static func shouldReplace(
        request current: WebhookRequest,
        with proposed: WebhookRequest
    ) -> Bool {
        shouldReplaceInvocations.append((current, proposed))
        return shouldReplace
    }

    var request: Promise<WebhookRequest>?
    var result: Promise<Any>?

    func handle(
        request: Promise<WebhookRequest>,
        result: Promise<Any>
    ) -> Guarantee<WebhookResponseHandlerResult> {
        self.request = request
        self.result = result
        return .value(Self.returnedResult ?? .default)
    }
}
