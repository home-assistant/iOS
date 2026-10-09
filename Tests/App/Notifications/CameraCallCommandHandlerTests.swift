@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

final class CameraCallCommandHandlerTests: XCTestCase {
    private var servers: FakeServerManager!
    private var reportedRequests: [CameraCallRequest] = []
    private var reportError: Error?

    override func setUp() {
        super.setUp()
        servers = FakeServerManager()
        servers.addFake()
        reportedRequests = []
        reportError = nil
    }

    func testACallCommandRingsForTheCamera() {
        let handled = expectation(description: "handled")

        makeHandler().handle(["entity_id": "camera.front_door"]).done {
            handled.fulfill()
        }.catch { error in
            XCTFail("Unexpected error \(error)")
        }

        wait(for: [handled], timeout: 5)
        XCTAssertEqual(reportedRequests.map(\.cameraEntityId), ["camera.front_door"])
    }

    func testACallCommandWithoutACameraIsRejected() {
        let rejected = expectation(description: "rejected")

        makeHandler().handle(["entity_id": "light.kitchen"]).done {
            XCTFail("A light cannot call")
        }.catch { error in
            XCTAssertEqual(
                error as? CameraCallCommandHandler.CameraCallCommandError,
                .missingCamera
            )
            rejected.fulfill()
        }

        wait(for: [rejected], timeout: 5)
        XCTAssertTrue(reportedRequests.isEmpty)
    }

    func testACallCallKitRefusesFailsTheCommand() {
        reportError = NSError(domain: "CallKit", code: 1)
        let rejected = expectation(description: "rejected")

        makeHandler().handle(["entity_id": "camera.front_door"]).done {
            XCTFail("CallKit refused the call")
        }.catch { error in
            XCTAssertEqual((error as NSError).domain, "CallKit")
            rejected.fulfill()
        }

        wait(for: [rejected], timeout: 5)
    }

    private func makeHandler() -> CameraCallCommandHandler {
        var handler = CameraCallCommandHandler()
        handler.makeRequest = { [servers] payload in
            CameraCallRequest(payload: payload, servers: servers!, entityName: { _, _ in nil })
        }
        handler.reportIncomingCall = { [weak self] request, completion in
            self?.reportedRequests.append(request)
            completion(self?.reportError)
        }
        return handler
    }
}
