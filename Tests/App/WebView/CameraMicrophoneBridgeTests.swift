@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

final class CameraMicrophoneBridgeTests: XCTestCase {
    private struct EndedSession: Equatable {
        let cameraEntityId: String
        let error: CameraMicrophoneError
    }

    private var notificationCenter: NotificationCenter!
    private var bridge: CameraMicrophoneBridge!
    private var sessions: [FakeCameraMicrophoneSession] = []
    private var startOutcomes: [CameraMicrophoneError?] = []
    private var endedSessions: [EndedSession] = []
    private let server = ServerFixture.standard

    override func setUp() {
        super.setUp()
        notificationCenter = NotificationCenter()
        sessions = []
        startOutcomes = []
        endedSessions = []
        bridge = CameraMicrophoneBridge(notificationCenter: notificationCenter) { [weak self] server, cameraEntityId in
            let session = FakeCameraMicrophoneSession(server: server, cameraEntityId: cameraEntityId)
            self?.sessions.append(session)
            return session
        }
        bridge.onSessionEnded = { [weak self] cameraEntityId, error in
            self?.endedSessions.append(.init(cameraEntityId: cameraEntityId, error: error))
        }
    }

    override func tearDown() {
        bridge = nil
        notificationCenter = nil
        sessions = []
        super.tearDown()
    }

    func testStartOpensASessionForTheCameraOnTheServer() throws {
        start("camera.front_door")

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.cameraEntityId, "camera.front_door")
        XCTAssertEqual(session.server.identifier, server.identifier)
        XCTAssertEqual(session.startCount, 1)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")
        XCTAssertTrue(startOutcomes.isEmpty, "The start is only answered once the session is up")

        session.connect()

        XCTAssertEqual(startOutcomes, [nil])
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")
    }

    func testAFailedStartLeavesNoActiveSession() throws {
        start("camera.front_door")

        try XCTUnwrap(sessions.first).fail(.microphoneDenied)

        XCTAssertEqual(startOutcomes, [.microphoneDenied])
        XCTAssertNil(bridge.activeCameraEntityId)
        XCTAssertTrue(endedSessions.isEmpty)
    }

    func testStartingAnotherCameraInterruptsTheConnectedOneAndReportsIt() throws {
        start("camera.front_door")
        try XCTUnwrap(sessions.first).connect()

        start("camera.garden")

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].stopCount, 1)
        XCTAssertEqual(endedSessions, [.init(cameraEntityId: "camera.front_door", error: .interrupted)])
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.garden")
    }

    func testStartingAnotherCameraWhileTheFirstIsConnectingAnswersTheFirstStart() throws {
        start("camera.front_door")

        start("camera.garden")

        XCTAssertEqual(startOutcomes, [.interrupted])
        XCTAssertEqual(sessions[0].stopCount, 1)
        XCTAssertTrue(endedSessions.isEmpty)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.garden")
    }

    func testStopOnlyEndsTheSessionOfTheCameraItNames() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect()

        bridge.stop(cameraEntityId: "camera.garden")
        XCTAssertEqual(session.stopCount, 0)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")

        bridge.stop(cameraEntityId: "camera.front_door")
        XCTAssertEqual(session.stopCount, 1)
        XCTAssertNil(bridge.activeCameraEntityId)
        XCTAssertTrue(endedSessions.isEmpty, "The frontend asked for this stop, so it is not told about it")
    }

    func testStopWithoutACameraEndsWhicheverSessionIsActive() throws {
        start("camera.front_door")

        bridge.stop(cameraEntityId: nil)

        XCTAssertEqual(try XCTUnwrap(sessions.first).stopCount, 1)
        XCTAssertNil(bridge.activeCameraEntityId)
    }

    func testStopWithoutASessionDoesNothing() {
        bridge.stop(cameraEntityId: nil)

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertTrue(endedSessions.isEmpty)
    }

    func testASessionEndingOnItsOwnIsReported() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect()

        session.end(.connectionFailed)

        XCTAssertEqual(endedSessions, [.init(cameraEntityId: "camera.front_door", error: .connectionFailed)])
        XCTAssertNil(bridge.activeCameraEntityId)
    }

    func testAnEndFromASessionThatWasAlreadyReplacedIsIgnored() throws {
        start("camera.front_door")
        let replaced = try XCTUnwrap(sessions.first)
        replaced.connect()
        start("camera.garden")

        replaced.end(.connectionFailed)

        XCTAssertEqual(endedSessions, [.init(cameraEntityId: "camera.front_door", error: .interrupted)])
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.garden")
    }

    func testGoingToTheBackgroundInterruptsTheSessionAndReportsIt() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect()

        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(endedSessions, [.init(cameraEntityId: "camera.front_door", error: .interrupted)])
        XCTAssertNil(bridge.activeCameraEntityId)
    }

    func testGoingToTheBackgroundWithoutASessionDoesNothing() {
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertTrue(endedSessions.isEmpty)
    }

    func testReleasingTheBridgeStopsTheActiveSession() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)

        bridge = nil
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertEqual(session.stopCount, 1)
    }

    // MARK: - Helpers

    private func start(_ cameraEntityId: String) {
        bridge.start(cameraEntityId: cameraEntityId, server: server) { [weak self] result in
            switch result {
            case .success:
                self?.startOutcomes.append(nil)
            case let .failure(error):
                self?.startOutcomes.append(error)
            }
        }
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 30.0)
    }
}
