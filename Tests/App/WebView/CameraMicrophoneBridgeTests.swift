@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

final class CameraMicrophoneBridgeTests: XCTestCase {
    private struct Report: Equatable {
        let sessionId: String
        let microphoneLevel: Double
    }

    private enum StartOutcome: Equatable {
        case started(sessionId: String)
        case failed(CameraMicrophoneError)
    }

    private var notificationCenter: NotificationCenter!
    private var bridge: CameraMicrophoneBridge!
    private var sessions: [FakeCameraMicrophoneSession] = []
    private var startOutcomes: [StartOutcome] = []
    private var endedSessionIds: [String] = []
    private var reports: [Report] = []
    private var haptics: SpyImpactFeedbackGenerator!
    private var originalImpactFeedback: ImpactFeedbackGeneratorProtocol!
    private let server = ServerFixture.standard

    override func setUp() {
        super.setUp()
        notificationCenter = NotificationCenter()
        sessions = []
        startOutcomes = []
        endedSessionIds = []
        reports = []
        originalImpactFeedback = Current.impactFeedback
        haptics = SpyImpactFeedbackGenerator()
        Current.impactFeedback = haptics
        bridge = CameraMicrophoneBridge(notificationCenter: notificationCenter) { [weak self] server, cameraEntityId in
            let session = FakeCameraMicrophoneSession(server: server, cameraEntityId: cameraEntityId)
            self?.sessions.append(session)
            return session
        }
        bridge.onSessionEnded = { [weak self] sessionId in
            self?.endedSessionIds.append(sessionId)
        }
        bridge.onSessionReport = { [weak self] sessionId, microphoneLevel in
            self?.reports.append(.init(sessionId: sessionId, microphoneLevel: microphoneLevel))
        }
    }

    override func tearDown() {
        bridge = nil
        notificationCenter = nil
        sessions = []
        Current.impactFeedback = originalImpactFeedback
        super.tearDown()
    }

    func testStartOpensASessionForTheCameraOnTheServer() throws {
        start("camera.front_door")

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.cameraEntityId, "camera.front_door")
        XCTAssertEqual(session.server.identifier, server.identifier)
        XCTAssertEqual(session.startCount, 1)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")
        XCTAssertTrue(startOutcomes.isEmpty)

        session.connect(sessionId: "session-1")

        XCTAssertEqual(startOutcomes, [.started(sessionId: "session-1")])
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")
    }

    func testAFailedStartLeavesNoActiveSession() throws {
        start("camera.front_door")

        try XCTUnwrap(sessions.first).fail(.microphoneDenied)

        XCTAssertEqual(startOutcomes, [.failed(.microphoneDenied)])
        XCTAssertNil(bridge.activeCameraEntityId)
        XCTAssertTrue(endedSessionIds.isEmpty)
    }

    func testStartingAnotherStreamInterruptsTheConnectedOneAndReportsIt() throws {
        start("camera.front_door")
        try XCTUnwrap(sessions.first).connect(sessionId: "session-1")

        start("camera.garden")

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].stopCount, 1)
        XCTAssertEqual(endedSessionIds, ["session-1"])
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.garden")
    }

    func testStartingAnotherStreamWhileTheFirstIsConnectingAnswersTheFirstStart() throws {
        start("camera.front_door")

        start("camera.garden")

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        XCTAssertEqual(sessions[0].stopCount, 1)
        XCTAssertTrue(endedSessionIds.isEmpty)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.garden")
    }

    func testStopOnlyEndsTheSessionItNames() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "session-1")

        bridge.stop(sessionId: "session-2")
        XCTAssertEqual(session.stopCount, 0)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")

        bridge.stop(sessionId: "session-1")
        XCTAssertEqual(session.stopCount, 1)
        XCTAssertNil(bridge.activeCameraEntityId)
        XCTAssertTrue(endedSessionIds.isEmpty)
    }

    func testStopDoesNotEndAStreamThatIsStillConnecting() throws {
        start("camera.front_door")

        bridge.stop(sessionId: "session-1")

        XCTAssertEqual(try XCTUnwrap(sessions.first).stopCount, 0)
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.front_door")
    }

    func testStopActiveSessionEndsWhicheverSessionIsActive() throws {
        start("camera.front_door")

        bridge.stopActiveSession()

        XCTAssertEqual(try XCTUnwrap(sessions.first).stopCount, 1)
        XCTAssertNil(bridge.activeCameraEntityId)
        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
    }

    func testStoppingWithoutASessionDoesNothing() {
        bridge.stop(sessionId: "session-1")
        bridge.stopActiveSession()

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertTrue(endedSessionIds.isEmpty)
    }

    func testASessionEndingOnItsOwnIsReported() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "session-1")

        session.end(.connectionFailed)

        XCTAssertEqual(endedSessionIds, ["session-1"])
        XCTAssertNil(bridge.activeCameraEntityId)
    }

    func testAnEndFromASessionThatWasAlreadyReplacedIsIgnored() throws {
        start("camera.front_door")
        let replaced = try XCTUnwrap(sessions.first)
        replaced.connect(sessionId: "session-1")
        start("camera.garden")

        replaced.end(.connectionFailed)

        XCTAssertEqual(endedSessionIds, ["session-1"])
        XCTAssertEqual(bridge.activeCameraEntityId, "camera.garden")
    }

    func testTheMicrophoneLevelOfTheActiveSessionIsReported() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "session-1")

        session.reportMicrophoneLevel(0.42)

        XCTAssertEqual(reports, [.init(sessionId: "session-1", microphoneLevel: 0.42)])
    }

    func testTheMicrophoneLevelOfAReplacedSessionIsIgnored() throws {
        start("camera.front_door")
        let replaced = try XCTUnwrap(sessions.first)
        replaced.connect(sessionId: "session-1")
        start("camera.garden")

        replaced.reportMicrophoneLevel(0.42)

        XCTAssertTrue(reports.isEmpty)
    }

    func testGoingToTheBackgroundInterruptsTheSessionAndReportsIt() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "session-1")

        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(endedSessionIds, ["session-1"])
        XCTAssertNil(bridge.activeCameraEntityId)
    }

    func testGoingToTheBackgroundWithoutASessionDoesNothing() {
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertTrue(endedSessionIds.isEmpty)
    }

    func testReleasingTheBridgeStopsTheActiveSession() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)

        bridge = nil
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertEqual(session.stopCount, 1)
    }

    // MARK: - Haptics

    func testTheMicrophoneGoingLivePlaysARigidImpact() throws {
        start("camera.front_door")
        XCTAssertTrue(haptics.feedbacks.isEmpty)

        try XCTUnwrap(sessions.first).connect(sessionId: "session-1")

        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid)])
    }

    func testAFailedStartPlaysTheErrorNotification() throws {
        start("camera.front_door")

        try XCTUnwrap(sessions.first).fail(.timedOut)

        XCTAssertEqual(haptics.feedbacks, [.notification(.error)])
    }

    func testAnInterruptedStartPlaysNoHaptic() {
        start("camera.front_door")

        start("camera.garden")

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        XCTAssertTrue(haptics.feedbacks.isEmpty)
    }

    func testStoppingALiveStreamPlaysASoftImpact() throws {
        start("camera.front_door")
        try XCTUnwrap(sessions.first).connect(sessionId: "session-1")

        bridge.stop(sessionId: "session-1")

        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .impact(.soft)])
    }

    func testStoppingAStreamThatHasNotGoneLivePlaysNoHaptic() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.sessionId = "session-1"

        bridge.stop(sessionId: "session-1")

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertTrue(haptics.feedbacks.isEmpty)
    }

    func testALiveStreamDroppingOnItsOwnPlaysTheWarningNotification() throws {
        start("camera.front_door")
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "session-1")

        session.end(.connectionFailed)

        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .notification(.warning)])
    }

    func testSwitchingCamerasWhileLiveOnlyPlaysTheNewStreamGoingLive() throws {
        start("camera.front_door")
        try XCTUnwrap(sessions.first).connect(sessionId: "session-1")

        start("camera.garden")
        sessions[1].connect(sessionId: "session-2")

        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .impact(.rigid)])
    }

    func testEndingALiveStreamWithoutTheUserPlaysNoHaptic() throws {
        start("camera.front_door")
        try XCTUnwrap(sessions.first).connect(sessionId: "session-1")
        bridge.stopActiveSession()

        start("camera.garden")
        sessions[1].connect(sessionId: "session-2")
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .impact(.rigid)])
    }

    // MARK: - Helpers

    private func start(_ cameraEntityId: String) {
        bridge.start(cameraEntityId: cameraEntityId, server: server) { [weak self] result in
            switch result {
            case let .success(sessionId):
                self?.startOutcomes.append(.started(sessionId: sessionId))
            case let .failure(error):
                self?.startOutcomes.append(.failed(error))
            }
        }
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 30.0)
    }
}
