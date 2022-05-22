import Foundation
import ObjectMapper
import OHHTTPStubs
import PromiseKit
@testable import Shared
import XCTest

class WebhookManagerTests: XCTestCase {
    private var manager: WebhookManager!
    private var api1: FakeHassAPI!
    private var api2: FakeHassAPI!
    private var webhookURL1: URL!
    private var webhookURL2: URL!

    override func setUp() {
        super.setUp()

        api1 = FakeHassAPI(server: .fake())
        api2 = FakeHassAPI(server: .fake())
        webhookURL1 = api1.server.info.connection.webhookURL()
        webhookURL2 = api2.server.info.connection.webhookURL()

        manager = WebhookManager()
    }

    override func tearDown() {
        super.tearDown()
        HTTPStubs.removeAllStubs()

        ReplacingTestHandler.reset()

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
            for _ in 0 ..< count {
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

    func testAuthenticationChallengeUnknownServer() throws {
        let task = manager.currentRegularSessionInfo.session.dataTask(
            with: URLRequest(url: URL(string: "http://example.com")!),
            completionHandler: { _, _, _ in }
        )

        let expectation = expectation(description: "completion handler")
        manager.urlSession(
            manager.currentRegularSessionInfo.session,
            task: task,
            didReceive: try SecTrust.unitTestDotExampleDotCom1.authenticationChallenge(),
            completionHandler: { disposition, credential in
                XCTAssertEqual(disposition, .performDefaultHandling)
                XCTAssertNil(credential)
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 10.0)
    }

    func testSendingEphemeralFailsEntirely() {
        let expectedError = URLError(.timedOut)
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(error: expectedError)
        })

        XCTAssertThrowsError(try hang(manager.sendEphemeral(server: api1.server, request: expectedRequest))) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
        }
    }

    func testSendingEphemeralFailsOnceThenSucceeds() {
        var shouldFail = true
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)

            if shouldFail {
                shouldFail = false
                return HTTPStubsResponse(error: URLError(.notConnectedToInternet))
            } else {
                return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: [:])
            }
        })

        XCTAssertNoThrow(try hang(manager.sendEphemeral(server: api1.server, request: expectedRequest)))
        XCTAssertFalse(shouldFail, "aka it did a loop")
    }

    func testSendingEphemeralFailsOnceThenSucceedsWithAChangedURL() {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        var nextConnectionInfo = ConnectionInfo(
            externalURL: URL(string: "http://example.changed"),
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "given_id",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: true,
            securityExceptions: .init()
        )

        let nextAPIWebhookURL = nextConnectionInfo.webhookURL()
        api1.server.info.connection = nextConnectionInfo

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(error: URLError(.notConnectedToInternet))
        })

        stub(condition: { req in req.url == nextAPIWebhookURL }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: [:])
        })

        XCTAssertNoThrow(try hang(manager.sendEphemeral(server: api1.server, request: expectedRequest)))
    }

    func testSendingEphemeralExpectingString() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(data: #""result""#.data(using: .utf8)!, statusCode: 200, headers: [:])
        })

        XCTAssertEqual(try hang(manager.sendEphemeral(server: api1.server, request: expectedRequest)), "result")
    }

    func testSendingEphemeralExpectingStringButGettingObject() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(jsonObject: ["bob": "your_uncle"], statusCode: 200, headers: [:])
        })

        let promise: Promise<String> = manager.sendEphemeral(server: api1.server, request: expectedRequest)
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

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(
                jsonObject: Mapper<ExampleMappable>().toJSON(expectedResponse),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<ExampleMappable> = manager.sendEphemeral(server: api1.server, request: expectedRequest)
        XCTAssertEqual(try hang(promise), expectedResponse)
    }

    func testSendingEphemeralExpectingMappableObjectButFailing() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true, "etc": "yerp"])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(
                data: Data(),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<ExampleMappable> = manager.sendEphemeral(server: api1.server, request: expectedRequest)
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

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(
                jsonObject: Mapper<ExampleMappable>().toJSONArray([expectedResponse1, expectedResponse2]),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<[ExampleMappable]> = manager.sendEphemeral(server: api1.server, request: expectedRequest)
        XCTAssertEqual(try hang(promise), [expectedResponse1, expectedResponse2])
    }

    func testSendingEphemeralExpectingMappableArrayButFailing() throws {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true, "etc": "yerp"])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(
                data: Data(),
                statusCode: 200,
                headers: [:]
            )
        })

        let promise: Promise<[ExampleMappable]> = manager.sendEphemeral(server: api1.server, request: expectedRequest)
        XCTAssertThrowsError(try hang(promise)) { error in
            switch error as? WebhookError {
            case .unmappableValue:
                break
            default:
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testSendEphemeralProtectionSpace() throws {
        for shouldAddException in [true, false] {
            let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])
            let networkSemaphore = DispatchSemaphore(value: 0)

            let trust = try SecTrust.unitTestDotExampleDotCom1

            if shouldAddException {
                api1.server.info.connection.securityExceptions.add(for: trust)
            } else {
                api1.server.info.connection.securityExceptions = .init()
            }

            let manager = manager!

            let stub = stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { _ in
                for session in [
                    manager.currentRegularSessionInfo.session,
                    manager.currentBackgroundSessionInfo.session,
                ] {
                    session.getAllTasks { [manager] tasks in
                        guard let task = tasks.first, tasks.count == 1 else {
                            // in the other session
                            return
                        }

                        manager.urlSession(
                            session,
                            task: task,
                            didReceive: trust.authenticationChallenge(),
                            completionHandler: { disposition, credential in
                                if shouldAddException {
                                    XCTAssertEqual(disposition, .useCredential)
                                    XCTAssertNotNil(credential)
                                    XCTAssertTrue(SecTrustEvaluateWithError(trust, nil))
                                } else {
                                    XCTAssertEqual(disposition, .rejectProtectionSpace)
                                    XCTAssertNil(credential)
                                }

                                networkSemaphore.signal()
                            }
                        )
                    }
                }

                networkSemaphore.wait()

                if shouldAddException {
                    return HTTPStubsResponse(data: #""result""#.data(using: .utf8)!, statusCode: 200, headers: [:])
                } else {
                    return HTTPStubsResponse(error: URLError(.secureConnectionFailed))
                }
            })

            if shouldAddException {
                XCTAssertEqual(try hang(manager.sendEphemeral(server: api1.server, request: expectedRequest)), "result")
            } else {
                XCTAssertThrowsError(try hang(manager.sendEphemeral(server: api1.server, request: expectedRequest)))
            }

            HTTPStubs.removeStub(stub)
        }
    }

    func testSendingTestSucceeds() throws {
        let expectedRequest = WebhookRequest(type: "get_config", data: [:])

        var newURL = URLComponents(url: webhookURL1, resolvingAgainstBaseURL: false)!
        newURL.host = "new.example.com"

        stub(condition: { req in req.url == newURL.url! }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(data: #""result""#.data(using: .utf8)!, statusCode: 200, headers: [:])
        })

        let promise = manager.sendTest(server: api1.server, baseURL: URL(string: "http://new.example.com:8123")!)
        XCTAssertNoThrow(try hang(promise))
    }

    func testSendingTestFails() throws {
        let expectedRequest = WebhookRequest(type: "get_config", data: [:])
        let expectedError = URLError(.timedOut)

        var newURL = URLComponents(url: webhookURL1, resolvingAgainstBaseURL: false)!
        newURL.host = "new.example.com"

        stub(condition: { req in req.url == newURL.url! }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(error: expectedError)
        })

        let promise = manager.sendTest(server: api1.server, baseURL: URL(string: "http://new.example.com:8123")!)

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
        }
    }

    func testSendingUnregisteredIdentifierErrors() {
        let promise1 = manager.send(
            identifier: .init(rawValue: "unregistered"),
            server: api1.server,
            request: .init(type: "test", data: ())
        )
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

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(error: expectedError)
        })

        XCTAssertThrowsError(try hang(manager.send(server: api1.server, request: expectedRequest))) { error in
            XCTAssertEqual((error as? URLError)?.code, expectedError.code)
        }
    }

    func testSendingPersistentUnhandledSucceeds() {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
        })

        XCTAssertNoThrow(try hang(manager.send(server: api1.server, request: expectedRequest)))
    }

    func testSendingPersistentUnhandledSucceedsWithoutServerCache() {
        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        Current.servers = with(FakeServerManager(initial: 0)) {
            _ = $0.add(identifier: api1.server.identifier, serverInfo: api1.server.info)
        }

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [self, api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            manager.serverCache.removeAll()
            return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
        })

        XCTAssertNoThrow(try hang(manager.send(server: api1.server, request: expectedRequest)))
    }

    func testSendingPersistentWithExistingResolvesBothPromises() throws {
        let request1 = WebhookRequest(type: "webhook_name", data: ["json": true])
        let request2 = WebhookRequest(type: "webhook_name", data: ["elephant": true])

        let request1Expectation = expectation(description: "request1")
        let request1Blocking = expectation(description: "request1-blocking")

        let identifier = WebhookResponseIdentifier(rawValue: "replacing")
        manager.register(responseHandler: ReplacingTestHandler.self, for: identifier)

        var pendingPromise1: Promise<Void>?
        var pendingPromise2: Promise<Void>?

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            // second one, the one we want to not be cancelled
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request2, server: api1!.server)
            return HTTPStubsResponse(jsonObject: ["result": 2], statusCode: 200, headers: nil)
        })

        var stub1: HTTPStubsDescriptor?
        stub1 = stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [manager, api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request1, server: api1!.server)
            HTTPStubs.removeStub(stub1!)

            // first one, the one we want to cancel
            pendingPromise2 = manager!.send(identifier: identifier, server: api1!.server, request: request2)
            request1Expectation.fulfill()

            self.wait(for: [request1Blocking], timeout: 100.0)
            return HTTPStubsResponse(jsonObject: ["result": 1], statusCode: 200, headers: nil)
        })

        pendingPromise1 = manager.send(identifier: identifier, server: api1.server, request: request1)

        wait(for: [request1Expectation], timeout: 10.0)

        guard let promise1 = pendingPromise1, let promise2 = pendingPromise2 else {
            XCTFail("expected promises")
            return
        }

        XCTAssertThrowsError(try hang(promise1)) { error in
            XCTAssertEqual(error as? WebhookError, .replaced)
        }
        XCTAssertNoThrow(try hang(promise2))

        request1Blocking.fulfill()

        XCTAssertEqual(ReplacingTestHandler.createdHandlers.count, 1)
        let request = try hang(ReplacingTestHandler.createdHandlers[0].request!)
        let result = try hang(ReplacingTestHandler.createdHandlers[0].result!)

        XCTAssertEqualWebhookRequest(request, request2, server: api1.server)
        XCTAssertEqual((result as? [String: Any])?["result"] as? Int, 2)
    }

    func testSendingPersistentOnRegularSessionWithExistingDoesntCancelEphemeral() throws {
        Current.isBackgroundRequestsImmediate = { false }

        let request1 = WebhookRequest(type: "webhook_name", data: ["json": true])
        let request2 = WebhookRequest(type: "webhook_name", data: ["elephant": true])

        let request1Expectation = expectation(description: "request1")
        let request1Blocking = expectation(description: "request1-blocking")

        let identifier = WebhookResponseIdentifier(rawValue: "replacing")
        manager.register(responseHandler: ReplacingTestHandler.self, for: identifier)

        var pendingPromise1: Promise<[String: Int]>?
        var pendingPromise2: Promise<Void>?

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            // second one, the one we want to not be cancelled
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request2, server: api1!.server)
            return HTTPStubsResponse(jsonObject: ["result": 2], statusCode: 200, headers: nil)
        })

        var stub1: HTTPStubsDescriptor?
        stub1 = stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [manager, api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request1, server: api1!.server)
            HTTPStubs.removeStub(stub1!)

            // first one, the one we want to make sure isn't cancelled
            pendingPromise2 = manager!.send(identifier: identifier, server: api1!.server, request: request2)
            request1Expectation.fulfill()

            self.wait(for: [request1Blocking], timeout: 100.0)
            return HTTPStubsResponse(jsonObject: ["result": 1], statusCode: 200, headers: nil)
        })

        pendingPromise1 = manager.sendEphemeral(server: api1.server, request: request1)

        wait(for: [request1Expectation], timeout: 10.0)

        guard let promise1 = pendingPromise1, let promise2 = pendingPromise2 else {
            XCTFail("expected promises")
            return
        }

        XCTAssertNoThrow(try hang(promise2))
        request1Blocking.fulfill()

        XCTAssertEqual(try hang(promise1), ["result": 1])

        XCTAssertEqual(ReplacingTestHandler.createdHandlers.count, 1)
        let createdRequest = try hang(XCTUnwrap(ReplacingTestHandler.createdHandlers[0].request))
        let createdResult = try hang(XCTUnwrap(ReplacingTestHandler.createdHandlers[0].result))

        XCTAssertEqualWebhookRequest(request2, createdRequest, server: api1.server)
        XCTAssertEqual((createdResult as? [String: Any])?["result"] as? Int, 2)
    }

    func testSendingPersistentOnRegularSessionWithExistingResolvesBothPromises() throws {
        Current.isBackgroundRequestsImmediate = { false }

        let request1 = WebhookRequest(type: "webhook_name", data: ["json": true])
        let request2 = WebhookRequest(type: "webhook_name", data: ["elephant": true])

        let request1Expectation = expectation(description: "request1")
        let request1Blocking = expectation(description: "request1-blocking")

        let identifier = WebhookResponseIdentifier(rawValue: "replacing")
        manager.register(responseHandler: ReplacingTestHandler.self, for: identifier)

        var pendingPromise1: Promise<Void>?
        var pendingPromise2: Promise<Void>?

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            // second one, the one we want to not be cancelled
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request2, server: api1!.server)
            return HTTPStubsResponse(jsonObject: ["result": 2], statusCode: 200, headers: nil)
        })

        var stub1: HTTPStubsDescriptor?
        stub1 = stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [manager, api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request1, server: api1!.server)
            HTTPStubs.removeStub(stub1!)

            // first one, the one we want to cancel
            pendingPromise2 = manager!.send(identifier: identifier, server: api1!.server, request: request2)
            request1Expectation.fulfill()

            self.wait(for: [request1Blocking], timeout: 100.0)
            return HTTPStubsResponse(jsonObject: ["result": 1], statusCode: 200, headers: nil)
        })

        pendingPromise1 = manager.send(identifier: identifier, server: api1.server, request: request1)

        wait(for: [request1Expectation], timeout: 10.0)

        guard let promise1 = pendingPromise1, let promise2 = pendingPromise2 else {
            XCTFail("expected promises")
            return
        }

        XCTAssertThrowsError(try hang(promise1)) { error in
            XCTAssertEqual(error as? WebhookError, .replaced)
        }
        XCTAssertNoThrow(try hang(promise2))

        request1Blocking.fulfill()

        XCTAssertEqual(ReplacingTestHandler.createdHandlers.count, 1)
        let request = try hang(ReplacingTestHandler.createdHandlers[0].request!)
        let result = try hang(ReplacingTestHandler.createdHandlers[0].result!)

        XCTAssertEqualWebhookRequest(request, request2, server: api1.server)
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

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request2, server: api1!.server)
            DispatchQueue.main.async { request1Blocking.fulfill() }
            return HTTPStubsResponse(jsonObject: ["result": 2], statusCode: 200, headers: nil)
        })

        var stub1: HTTPStubsDescriptor?
        stub1 = stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [manager, api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, request1, server: api1!.server)
            HTTPStubs.removeStub(stub1!)

            pendingPromise2 = manager!.send(identifier: identifier, server: api1!.server, request: request2)
            request1Expectation.fulfill()

            self.wait(for: [request1Blocking], timeout: 100.0)
            return HTTPStubsResponse(jsonObject: ["result": 1], statusCode: 200, headers: nil)
        })

        pendingPromise1 = manager.send(identifier: identifier, server: api1.server, request: request1)

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

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { _ in
            networkSemaphore.wait()
            return HTTPStubsResponse(jsonObject: ["result": true], statusCode: 200, headers: nil)
        })

        let promise1 = manager.send(identifier: .unhandled, server: api1.server, request: request1)
        let promise2 = manager.send(identifier: identifier, server: api1.server, request: request2)

        networkSemaphore.signal()
        networkSemaphore.signal()

        XCTAssertNoThrow(try hang(promise1))
        XCTAssertNoThrow(try hang(promise2))

        XCTAssertTrue(ReplacingTestHandler.shouldReplaceInvocations.isEmpty)
    }

    func testSendPersistentWhenBackgroundRequestsForcedDiscretionarySucceeds() {
        Current.isBackgroundRequestsImmediate = { false }

        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)
            return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
        })

        XCTAssertNoThrow(try hang(manager.send(server: api1.server, request: expectedRequest)))
    }

    func testSendPersistentWhenBackgroundRequestsForcedDiscretionaryFailsInitially() {
        Current.isBackgroundRequestsImmediate = { false }

        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        var hasFailed = false

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)

            if !hasFailed {
                hasFailed = true
                return HTTPStubsResponse(error: URLError(.timedOut))
            } else {
                return HTTPStubsResponse(jsonObject: ["hello": "goodbye"], statusCode: 200, headers: nil)
            }
        })

        XCTAssertNoThrow(try hang(manager.send(server: api1.server, request: expectedRequest)))
    }

    func testSendPersistentWhenBackgroundRequestsForcedDiscretionaryFailsEverything() {
        Current.isBackgroundRequestsImmediate = { false }

        let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])

        var hasFailed = false

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { [api1] request in
            XCTAssertEqualWebhookRequest(request.ohhttpStubs_httpBody, expectedRequest, server: api1!.server)

            if !hasFailed {
                hasFailed = true
                return HTTPStubsResponse(error: URLError(.timedOut))
            } else {
                return HTTPStubsResponse(error: URLError(.dnsLookupFailed))
            }
        })

        XCTAssertThrowsError(try hang(manager.send(server: api1.server, request: expectedRequest))) { error in
            XCTAssertEqual((error as? URLError)?.code, .dnsLookupFailed)
        }
    }

    func testSendPersistentPassively() throws {
        let request = WebhookRequest(type: "webhook_name", data: ["json": true])

        let networkExpectation = expectation(description: "network was invoked")
        let networkSemaphore = DispatchSemaphore(value: 0)

        stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { _ in
            networkSemaphore.wait()
            networkExpectation.fulfill()
            return HTTPStubsResponse(jsonObject: ["result": true], statusCode: 200, headers: nil)
        })

        let promise = manager.sendPassive(identifier: .unhandled, server: api1.server, request: request)

        // it should be complete before the network call completes, so wait for its signal before finishing the network
        XCTAssertNoThrow(try hang(promise))

        // clean up the semaphore we're using to block the network
        networkSemaphore.signal()

        // but we do want to make sure the network call actually took place
        wait(for: [networkExpectation], timeout: 10.0)
    }

    func testSendPersistentProtectionSpace() throws {
        // we want to fail through both regular & background, when failing
        Current.isBackgroundRequestsImmediate = { false }

        for shouldAddException in [true, false] {
            let expectedRequest = WebhookRequest(type: "webhook_name", data: ["json": true])
            let networkSemaphore = DispatchSemaphore(value: 0)

            let trust = try SecTrust.unitTestDotExampleDotCom1

            if shouldAddException {
                api1.server.info.connection.securityExceptions.add(for: trust)
            } else {
                api1.server.info.connection.securityExceptions = .init()
            }

            let manager = manager!

            let stub = stub(condition: { [webhookURL1] req in req.url == webhookURL1 }, response: { _ in
                for session in [
                    manager.currentRegularSessionInfo.session,
                    manager.currentBackgroundSessionInfo.session,
                ] {
                    session.getAllTasks { [manager] tasks in
                        guard let task = tasks.first, tasks.count == 1 else {
                            // in the other session
                            return
                        }

                        manager.urlSession(
                            session,
                            task: task,
                            didReceive: trust.authenticationChallenge(),
                            completionHandler: { disposition, credential in
                                if shouldAddException {
                                    XCTAssertEqual(disposition, .useCredential)
                                    XCTAssertNotNil(credential)
                                    XCTAssertTrue(SecTrustEvaluateWithError(trust, nil))
                                } else {
                                    XCTAssertEqual(disposition, .rejectProtectionSpace)
                                    XCTAssertNil(credential)
                                }

                                networkSemaphore.signal()
                            }
                        )
                    }
                }

                networkSemaphore.wait()

                if shouldAddException {
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                } else {
                    return HTTPStubsResponse(error: URLError(.secureConnectionFailed))
                }
            })

            if shouldAddException {
                XCTAssertNoThrow(try hang(manager.send(server: api1.server, request: expectedRequest)))
            } else {
                XCTAssertThrowsError(try hang(manager.send(server: api1.server, request: expectedRequest)))
            }

            HTTPStubs.removeStub(stub)
        }
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
    server: Server,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let mapper = Mapper<WebhookRequest>(context: WebhookRequestContext.server(server))
        let lhs = try mapper.map(JSONObject: try JSONSerialization.jsonObject(with: lhsData ?? Data(), options: []))
        XCTAssertEqualWebhookRequest(lhs, rhs, server: server, file: file, line: line)
    } catch {
        XCTFail("got error: \(error)", file: file, line: line)
    }
}

private func XCTAssertEqualWebhookRequest(
    _ lhs: WebhookRequest,
    _ rhs: WebhookRequest,
    server: Server,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let mapper = Mapper<WebhookRequest>(context: WebhookRequestContext.server(server))

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

private class FakeHassAPI: HomeAssistantAPI {}

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
