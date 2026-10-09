import AVFoundation
import CallKit
@testable import HomeAssistant
@testable import Shared
import XCTest

final class CameraCallManagerTests: XCTestCase {
    private var servers: FakeServerManager!
    private var provider: FakeCameraCallProvider!
    private var audio: FakeCameraCallAudio!
    private var sessions: [FakeCameraMicrophoneSession] = []
    private var manager: CameraCallManager!
    private var reportResults: [Error?] = []
    private let callUUID = UUID()

    override func setUp() {
        super.setUp()
        servers = FakeServerManager()
        servers.addFake()
        provider = FakeCameraCallProvider()
        audio = FakeCameraCallAudio()
        sessions = []
        reportResults = []
        manager = makeManager(unansweredTimeout: 30)
    }

    override func tearDown() {
        manager?.reset()
        manager = nil
        super.tearDown()
    }

    // MARK: - Ringing

    func testTheManagerHandlesCallKitActions() {
        XCTAssertTrue(provider.delegate === manager)
    }

    func testAnIncomingCallRingsWithTheCamerasName() throws {
        try ring()

        let reported = try XCTUnwrap(provider.reportedCalls.first)
        XCTAssertEqual(reported.uuid, callUUID)
        XCTAssertEqual(reported.update.localizedCallerName, "Front door")
        XCTAssertEqual(reported.update.remoteHandle?.value, "camera.front_door")
        XCTAssertFalse(reported.update.hasVideo)
        XCTAssertEqual(manager.activeCallUUID, callUUID)
        XCTAssertEqual(reportResults.count, 1)
        XCTAssertNil(reportResults.first ?? nil)
    }

    func testTheCallIsAudioOnlyWithoutCallFeatures() throws {
        let update = try CameraCallManager.update(for: request())

        XCTAssertEqual(update.remoteHandle?.type, .generic)
        XCTAssertFalse(update.hasVideo)
        XCTAssertFalse(update.supportsHolding)
        XCTAssertFalse(update.supportsGrouping)
        XCTAssertFalse(update.supportsUngrouping)
        XCTAssertFalse(update.supportsDTMF)
    }

    func testAnotherCallWhileOneIsRingingIsIgnored() throws {
        try ring()

        try ring(entityId: "camera.garden")

        XCTAssertEqual(provider.reportedCalls.count, 1)
        XCTAssertEqual(reportResults.count, 2)
        XCTAssertEqual(manager.activeCallUUID, callUUID)
    }

    func testACallCallKitRefusesIsForgotten() throws {
        provider.reportError = NSError(domain: "CallKit", code: 1)

        try ring()

        XCTAssertNil(manager.activeCallUUID)
        XCTAssertNotNil(reportResults.first ?? nil)
        XCTAssertFalse(manager.answerCall(uuid: callUUID))
    }

    func testAnUnansweredCallRingsOut() throws {
        manager = makeManager(unansweredTimeout: 0.2)

        try ring()
        spinMain(until: { !provider.endedCalls.isEmpty })

        XCTAssertEqual(provider.endedCalls, [.init(uuid: callUUID, reason: .unanswered)])
        XCTAssertNil(manager.activeCallUUID)
        XCTAssertTrue(audio.events.isEmpty)
    }

    func testAnsweringStopsTheRingOut() throws {
        manager = makeManager(unansweredTimeout: 0.2)
        try ring()

        manager.answerCall(uuid: callUUID)
        spinMain(for: 0.6)

        XCTAssertTrue(provider.endedCalls.isEmpty)
        XCTAssertEqual(manager.activeCallUUID, callUUID)
    }

    // MARK: - Answering

    func testAnsweringStreamsAudioWithTheCamera() throws {
        try ring()

        XCTAssertTrue(manager.answerCall(uuid: callUUID))

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.cameraEntityId, "camera.front_door")
        XCTAssertEqual(session.server.identifier, servers.all.first?.identifier)
        XCTAssertEqual(session.startCount, 1)
        XCTAssertEqual(audio.events, [.prepared])
    }

    func testAnsweringAnUnknownCallFails() throws {
        try ring()

        XCTAssertFalse(manager.answerCall(uuid: UUID()))
        XCTAssertTrue(sessions.isEmpty)
    }

    func testAConnectedCallTurnsTheMicrophoneOn() throws {
        let session = try answeredCall()

        session.connect(sessionId: "session-1")

        XCTAssertEqual(session.microphoneEnabledChanges, [true])
    }

    func testMutingWhileConnectingIsKeptOnceConnected() throws {
        let session = try answeredCall()

        XCTAssertTrue(manager.setMuted(true, uuid: callUUID))
        session.connect(sessionId: "session-1")

        XCTAssertEqual(session.microphoneEnabledChanges, [false, false])
    }

    func testMutingTogglesTheMicrophone() throws {
        let session = try answeredCall()
        session.connect(sessionId: "session-1")

        manager.setMuted(true, uuid: callUUID)
        manager.setMuted(false, uuid: callUUID)

        XCTAssertEqual(session.microphoneEnabledChanges, [true, false, true])
    }

    func testMutingAnUnknownCallFails() throws {
        try ring()

        XCTAssertFalse(manager.setMuted(true, uuid: UUID()))
    }

    // MARK: - Ending

    func testACallThatCannotConnectEndsAsFailed() throws {
        let session = try answeredCall()

        session.fail(.timedOut)

        XCTAssertEqual(provider.endedCalls, [.init(uuid: callUUID, reason: .failed)])
        XCTAssertNil(manager.activeCallUUID)
        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(audio.events, [.prepared, .finished])
    }

    func testACallThatLosesItsStreamEndsAsFailed() throws {
        let session = try answeredCall()
        session.connect(sessionId: "session-1")

        session.end(.connectionFailed)

        XCTAssertEqual(provider.endedCalls, [.init(uuid: callUUID, reason: .failed)])
        XCTAssertNil(manager.activeCallUUID)
        XCTAssertEqual(audio.events, [.prepared, .finished])
    }

    func testHangingUpStopsTheCameraAudio() throws {
        let session = try answeredCall()
        session.connect(sessionId: "session-1")

        XCTAssertTrue(manager.endCall(uuid: callUUID))

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(audio.events, [.prepared, .finished])
        XCTAssertTrue(provider.endedCalls.isEmpty)
        XCTAssertNil(manager.activeCallUUID)
    }

    func testDecliningARingingCallNeedsNoAudio() throws {
        try ring()

        XCTAssertTrue(manager.endCall(uuid: callUUID))

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertTrue(audio.events.isEmpty)
        XCTAssertNil(manager.activeCallUUID)
    }

    func testEndingAnUnknownCallFails() throws {
        try ring()

        XCTAssertFalse(manager.endCall(uuid: UUID()))
        XCTAssertEqual(manager.activeCallUUID, callUUID)
    }

    func testResettingEndsTheCall() throws {
        let session = try answeredCall()

        manager.reset()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertNil(manager.activeCallUUID)
    }

    func testANewCallCanRingOnceThePreviousOneEnded() throws {
        try ring()
        manager.endCall(uuid: callUUID)

        try ring(entityId: "camera.garden")

        XCTAssertEqual(provider.reportedCalls.count, 2)
        XCTAssertEqual(manager.activeCallUUID, callUUID)
    }

    // MARK: - Audio session

    func testCallKitAudioSessionChangesReachTheAudio() {
        manager.audioSessionDidActivate(AVAudioSession.sharedInstance())
        manager.audioSessionDidDeactivate(AVAudioSession.sharedInstance())

        XCTAssertEqual(audio.events, [.activated, .deactivated])
    }

    // MARK: - Helpers

    private func makeManager(unansweredTimeout: TimeInterval) -> CameraCallManager {
        CameraCallManager(
            provider: provider,
            audio: audio,
            makeSession: { [weak self] server, cameraEntityId in
                let session = FakeCameraMicrophoneSession(server: server, cameraEntityId: cameraEntityId)
                self?.sessions.append(session)
                return session
            },
            makeUUID: { [callUUID] in callUUID },
            timing: .init(unansweredTimeout: unansweredTimeout)
        )
    }

    private func request(entityId: String = "camera.front_door") throws -> CameraCallRequest {
        try XCTUnwrap(CameraCallRequest(
            payload: ["entity_id": entityId],
            servers: servers,
            entityName: { entityId, _ in entityId == "camera.front_door" ? "Front door" : nil }
        ))
    }

    private func ring(entityId: String = "camera.front_door") throws {
        let callRequest = try request(entityId: entityId)
        let reported = expectation(description: "reported")
        manager.reportIncomingCall(callRequest) { [weak self] error in
            self?.reportResults.append(error)
            reported.fulfill()
        }
        wait(for: [reported], timeout: 5)
    }

    private func answeredCall() throws -> FakeCameraMicrophoneSession {
        try ring()
        XCTAssertTrue(manager.answerCall(uuid: callUUID))
        return try XCTUnwrap(sessions.first)
    }

    private func spinMain(for interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }

    private func spinMain(
        until condition: () -> Bool,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "Timed out spinning the main run loop", file: file, line: line)
    }
}
