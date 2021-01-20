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
            tokenInfo: TokenInfo(
                accessToken: "accessToken",
                refreshToken: "refreshToken",
                expiration: Date()
            )
        )

        let connectionInfo = ConnectionInfo(
            externalURL: URL(string: "http://example.com"),
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "given_id",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil
        )
        webhookURL = connectionInfo.webhookURL

        Current.settingsStore.connectionInfo = connectionInfo
        Current.api = .value(api)

        manager = WebhookManager()
    }

    override func tearDown() {
        super.tearDown()
        HTTPStubs.removeAllStubs()

        ReplacingTestHandler.reset()

        Current.settingsStore.connectionInfo = nil
        Current.isBackgroundRequestsImmediate = { true }
    }

    func testBackgroundHandlingCallsCompletionHandler() {
        let (didInvokePromise, didInvokeSeal) = Promise<Void>.pending()

        manager.handleBackground(for: manager.currentBackgroundSessionInfo.identifier, completionHandler: {
            didInvokeSeal.fulfill(())
        })

        sendDidFinishEvents(for: manager.currentBackgroundSessionInfo)

        XCTAssertNoThrow(try hang(didInvokePromise))
    }

    func testBackgroundHandlingCallsCompletionHandlerWhenInvokedBefore() {
        let (didInvokePromise, didInvokeSeal) = Promise<Void>.pending()

        sendDidFinishEvents(for: manager.currentBackgroundSessionInfo)
        
        manager.handleBackground(for: manager.currentBackgroundSessionInfo.identifier, completionHandler: {
            didInvokeSeal.fulfill(())
        })

        XCTAssertNoThrow(try hang(didInvokePromise))
    }

    func testUnbalancedBackgroundHandlingDoesntCrash() {
        // not the best test: this will crash the test execution if it fails
        sendDidFinishEvents(for: manager.currentBackgroundSessionInfo)
    }

    func testBackgroundHandlingForExtensionCallsAppropriateCompletionHandler() {
        let mainIdentifier = manager.currentBackgroundSessionInfo.identifier
        let testIdentifier = manager.currentBackgroundSessionInfo.identifier + "-test" + UUID().uuidString

        let (mainPromise, mainSeal) = Promise<Void>.pending()
        let (testPromise, testSeal) = Promise<Void>.pending()

        manager.handleBackground(for: mainIdentifier, completionHandler: {
            mainSeal.fulfill(())
        })

        manager.handleBackground(for: testIdentifier, completionHandler: {
            testSeal.fulfill(())
        })

        func waitRunLoop(queue: DispatchQueue = .main, count: Int = 1) {
            let expectation = self.expectation(description: "run loop")
            expectation.expectedFulfillmentCount = count
            for _ in 0..<count {
                queue.async { expectation.fulfill() }
            }
            wait(for: [expectation], timeout: 10.0)
        }

        waitRunLoop()

        XCTAssertTrue(mainPromise.isPending)
        XCTAssertTrue(testPromise.isPending)

        sendDidFinishEvents(for: manager.currentBackgroundSessionInfo)

        waitRunLoop()

        XCTAssertFalse(mainPromise.isPending)
        XCTAssertTrue(testPromise.isPending)

        sendDidFinishEvents(for: manager.sessionInfos.first(where: {
            $0.identifier == testIdentifier
        })!)

        // for the completion block
        XCTAssertNoThrow(try hang(mainPromise))
        XCTAssertNoThrow(try hang(testPromise))

        // for the clearing of session infos
        waitRunLoop(
            queue: manager.currentBackgroundSessionInfo.session.delegateQueue.underlyingQueue!,
            count: 2
        )

        // inside baseball: make sure it deallocates any references to the extension background session but not the main
        XCTAssertTrue(manager.sessionInfos.contains(where: { $0.identifier == mainIdentifier }))
        XCTAssertFalse(manager.sessionInfos.contains(where: { $0.identifier == testIdentifier }))
    }

    func testSendingEphemeralFailsEntirely() {
        let expectedError = URLError(.timedOut)
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(error: expectedError)
        })

        XCTAssertThrowsError(try hang(manager.sendEphemeral(request: expectedRequest))) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
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

        let connectionInfo = ConnectionInfo(
            externalURL: URL(string: "http://example.changed"),
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "given_id",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil
        )

        let nextAPI = FakeHassAPI(
            tokenInfo: TokenInfo(
                accessToken: "accessToken",
                refreshToken: "refreshToken",
                expiration: Date()
            )
        )

        Current.settingsStore.connectionInfo = connectionInfo

        let nextAPIWebhookURL = connectionInfo.webhookURL

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

        Current.settingsStore.connectionInfo = nil
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
            switch error as? WebhookError {
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
            switch error as? WebhookError {
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
            switch error as? WebhookError {
            case .unmappableValue:
                break
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testSendingTestSucceeds() throws {
        let expectedRequest = WebhookRequest(type: "get_config", data: [:])

        var newURL = URLComponents(url: webhookURL, resolvingAgainstBaseURL: false)!
        newURL.host = "new.example.com"

        stub(condition: { req in req.url == newURL.url! }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(data: #""result""#.data(using: .utf8)!, statusCode: 200, headers: [:])
        })

        let promise = manager.sendTest(baseURL: URL(string: "http://new.example.com")!)
        XCTAssertNoThrow(try hang(promise))
    }

    func testSendingTestFails() throws {
        let expectedRequest = WebhookRequest(type: "get_config", data: [:])
        let expectedError = URLError(.timedOut)

        var newURL = URLComponents(url: webhookURL, resolvingAgainstBaseURL: false)!
        newURL.host = "new.example.com"

        stub(condition: { req in req.url == newURL.url! }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(error: expectedError)
        })

        let promise = manager.sendTest(baseURL: URL(string: "http://new.example.com")!)

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
        }
    }

    func testSendingUnregisteredIdentifierErrors() {
        let promise1 = manager.send(identifier: .init(rawValue: "unregistered"), request: .init(type: "test", data: ()))
        XCTAssertThrowsError(try hang(promise1)) { error in
            switch error as? WebhookError {
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

    func testSendPersistentWhenBackgroundRequestsForcedDiscretionarySucceeds() {
        Current.isBackgroundRequestsImmediate = { false }

        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)
            return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
        })

        XCTAssertNoThrow(try hang(manager.send(request: expectedRequest)))
    }

    func testSendPersistentWhenBackgroundRequestsForcedDiscretionaryFailsInitially() {
        Current.isBackgroundRequestsImmediate = { false }

        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        var hasFailed = false

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)

            if !hasFailed {
                hasFailed = true
                return HTTPStubsResponse(error: URLError(.timedOut))
            } else {
                return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
            }
        })

        XCTAssertNoThrow(try hang(manager.send(request: expectedRequest)))
    }

    func testSendPersistentWhenBackgroundRequestsForcedDiscretionaryFailsEverything() {
        Current.isBackgroundRequestsImmediate = { false }

        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        var hasFailed = false

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest)

            if !hasFailed {
                hasFailed = true
                return HTTPStubsResponse(error: URLError(.timedOut))
            } else {
                return HTTPStubsResponse(error: URLError(.dnsLookupFailed))
            }
        })

        XCTAssertThrowsError(try hang(manager.send(request: expectedRequest))) { error in
            XCTAssertEqual((error as? URLError)?.code, .dnsLookupFailed)
        }
    }

    func testSendPersistentPassively() throws {
        let request = WebhookRequest(type: "webhook_name", data: ["json": true])

        let networkExpectation = expectation(description: "network was invoked")
        let networkSemaphore = DispatchSemaphore(value: 0)

        stub(condition: { [webhookURL] req in req.url == webhookURL }, response: { _ in
            networkSemaphore.wait()
            networkExpectation.fulfill()
            return HTTPStubsResponse(jsonObject: ["result": true], statusCode: 200, headers: nil)
        })

        let promise = manager.sendPassive(identifier: .unhandled, request: request)

        // it should be complete before the network call completes, so wait for its signal before finishing the network
        XCTAssertNoThrow(try hang(promise))

        // clean up the semaphore we're using to block the network
        networkSemaphore.signal()

        // but we do want to make sure the network call actually took place
        wait(for: [networkExpectation], timeout: 10.0)
    }

    private func sendDidFinishEvents(for sessionInfo: WebhookSessionInfo) {
        sessionInfo.session.delegateQueue.addOperation {
            sessionInfo.session.delegate?.urlSessionDidFinishEvents?(forBackgroundURLSession: sessionInfo.session)
        }
        sessionInfo.session.delegateQueue.waitUntilAllOperationsAreFinished()
    }
}

private func XCTAssertEqualWebhookRequest(
    _ lhsData: Data?,
    _ rhs: WebhookRequest,
    file: StaticString = #filePath,
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
    file: StaticString = #filePath,
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
