@testable import HomeAssistant
import UIKit
import XCTest

final class MicrophoneRecordingBridgeTests: XCTestCase {
    private enum StartOutcome: Equatable {
        case started(sessionId: String)
        case failed(MicrophoneRecordingError)
    }

    private struct Ended: Equatable {
        let sessionId: String
        let reason: MicrophoneRecordingStopReason
    }

    private var notificationCenter: NotificationCenter!
    private var bridge: MicrophoneRecordingBridge!
    private var sessions: [FakeMicrophoneRecordingSession] = []
    private var startOutcomes: [StartOutcome] = []
    private var ended: [Ended] = []

    override func setUp() {
        super.setUp()
        notificationCenter = NotificationCenter()
        sessions = []
        startOutcomes = []
        ended = []
        bridge = MicrophoneRecordingBridge(notificationCenter: notificationCenter) { [weak self] in
            let session = FakeMicrophoneRecordingSession(sessionId: "session-\((self?.sessions.count ?? 0) + 1)")
            self?.sessions.append(session)
            return session
        }
        bridge.onSessionEnded = { [weak self] sessionId, reason in
            self?.ended.append(Ended(sessionId: sessionId, reason: reason))
        }
    }

    override func tearDown() {
        bridge = nil
        notificationCenter = nil
        sessions = []
        super.tearDown()
    }

    func testStartAnswersWithTheSessionOnceItRecords() throws {
        start()

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.startCount, 1)
        XCTAssertEqual(bridge.activeSessionId, "session-1")
        XCTAssertTrue(startOutcomes.isEmpty)

        session.record()

        XCTAssertEqual(startOutcomes, [.started(sessionId: "session-1")])
        XCTAssertEqual(bridge.activeSessionId, "session-1")
    }

    func testAFailedStartLeavesNoActiveSession() throws {
        start()

        try XCTUnwrap(sessions.first).fail(.microphoneDenied)

        XCTAssertEqual(startOutcomes, [.failed(.microphoneDenied)])
        XCTAssertNil(bridge.activeSessionId)
        XCTAssertTrue(ended.isEmpty)
    }

    func testStopHandsOverTheRecordingOfTheSessionItNames() throws {
        start()
        let session = try XCTUnwrap(sessions.first)
        session.record()
        var results: [Result<MicrophoneRecording, MicrophoneRecordingError>] = []

        bridge.stop(sessionId: "session-1") { results.append($0) }
        XCTAssertEqual(session.finishCount, 1)
        XCTAssertNil(bridge.activeSessionId)

        session.deliver(.success(recording(sessionId: "session-1")))

        XCTAssertEqual(results, [.success(recording(sessionId: "session-1"))])
        XCTAssertTrue(ended.isEmpty)
    }

    func testStopForAnUnknownSessionIsNotFound() throws {
        start()
        let session = try XCTUnwrap(sessions.first)
        session.record()
        var results: [Result<MicrophoneRecording, MicrophoneRecordingError>] = []

        bridge.stop(sessionId: "session-2") { results.append($0) }

        XCTAssertEqual(results, [.failure(.sessionNotFound)])
        XCTAssertEqual(session.finishCount, 0)
        XCTAssertEqual(bridge.activeSessionId, "session-1")
    }

    func testStopForASessionThatIsStillStartingIsNotFound() throws {
        start()
        var results: [Result<MicrophoneRecording, MicrophoneRecordingError>] = []

        bridge.stop(sessionId: "session-1") { results.append($0) }

        XCTAssertEqual(results, [.failure(.sessionNotFound)])
        XCTAssertEqual(try XCTUnwrap(sessions.first).finishCount, 0)
    }

    func testARecordingTheSessionEndsOnItsOwnIsReportedAndKeptForStop() throws {
        start()
        let session = try XCTUnwrap(sessions.first)
        session.record()

        session.end(.maxDuration)

        XCTAssertEqual(ended, [Ended(sessionId: "session-1", reason: .maxDuration)])
        XCTAssertNil(bridge.activeSessionId)
        XCTAssertEqual(session.discardCount, 0)

        var results: [Result<MicrophoneRecording, MicrophoneRecordingError>] = []
        bridge.stop(sessionId: "session-1") { results.append($0) }
        session.deliver(.success(recording(sessionId: "session-1")))
        XCTAssertEqual(results, [.success(recording(sessionId: "session-1"))])

        bridge.stop(sessionId: "session-1") { results.append($0) }
        XCTAssertEqual(results.last, .failure(.sessionNotFound))
    }

    func testStartingAnotherRecordingStopsTheRunningOneAndKeepsIt() throws {
        start()
        let first = try XCTUnwrap(sessions.first)
        first.record()

        start()

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(first.stopCount, 1)
        XCTAssertEqual(first.discardCount, 0)
        XCTAssertEqual(ended, [Ended(sessionId: "session-1", reason: .replaced)])
        XCTAssertEqual(bridge.activeSessionId, "session-2")

        bridge.stop(sessionId: "session-1") { _ in }
        XCTAssertEqual(first.finishCount, 1)
    }

    func testStartingAnotherRecordingWhileTheFirstIsStartingAnswersTheFirstStart() throws {
        start()

        start()

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        XCTAssertEqual(sessions[0].discardCount, 1)
        XCTAssertTrue(ended.isEmpty)
        XCTAssertEqual(bridge.activeSessionId, "session-2")
    }

    func testAnEndFromASessionThatWasAlreadyReplacedIsIgnored() throws {
        start()
        let replaced = try XCTUnwrap(sessions.first)
        replaced.record()
        start()

        replaced.end(.failed)

        XCTAssertEqual(ended, [Ended(sessionId: "session-1", reason: .replaced)])
        XCTAssertEqual(bridge.activeSessionId, "session-2")
    }

    func testGoingToTheBackgroundStopsTheRecordingAndReportsIt() throws {
        start()
        let session = try XCTUnwrap(sessions.first)
        session.record()

        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(ended, [Ended(sessionId: "session-1", reason: .background)])
        XCTAssertNil(bridge.activeSessionId)
    }

    func testGoingToTheBackgroundWithoutARecordingDoesNothing() {
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        flushMainQueue()

        XCTAssertTrue(ended.isEmpty)
    }

    func testDiscardAllThrowsAwayTheRunningAndTheKeptRecordings() throws {
        start()
        let kept = try XCTUnwrap(sessions.first)
        kept.record()
        kept.end(.interrupted)
        start()
        let running = try XCTUnwrap(sessions.last)
        running.record()

        bridge.discardAll()

        XCTAssertEqual(kept.discardCount, 1)
        XCTAssertEqual(running.discardCount, 1)
        XCTAssertNil(bridge.activeSessionId)
        var results: [Result<MicrophoneRecording, MicrophoneRecordingError>] = []
        bridge.stop(sessionId: "session-1") { results.append($0) }
        XCTAssertEqual(results, [.failure(.sessionNotFound)])
    }

    func testReleasingTheBridgeDiscardsTheRecording() throws {
        start()
        let session = try XCTUnwrap(sessions.first)
        session.record()

        bridge = nil

        XCTAssertEqual(session.discardCount, 1)
    }

    // MARK: - Helpers

    private func start() {
        bridge.start { [weak self] result in
            switch result {
            case let .success(sessionId):
                self?.startOutcomes.append(.started(sessionId: sessionId))
            case let .failure(error):
                self?.startOutcomes.append(.failed(error))
            }
        }
    }

    private func recording(sessionId: String) -> MicrophoneRecording {
        MicrophoneRecording(sessionId: sessionId, audio: Data([1, 2, 3]), sampleRate: 16000, channels: 1, duration: 1.5)
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 30.0)
    }
}
