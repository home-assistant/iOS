import AVFoundation
@testable import HomeAssistant
import XCTest

final class MicrophoneRecordingSessionTests: XCTestCase {
    private enum SetupError: Error {
        case failed
    }

    private var directory: URL!
    private var notificationCenter: NotificationCenter!
    private var recorder: FakeMicrophoneAudioRecorder!
    private var madeRecorderURLs: [URL] = []
    private var endReasons: [MicrophoneRecordingStopReason] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        notificationCenter = NotificationCenter()
        recorder = FakeMicrophoneAudioRecorder()
        madeRecorderURLs = []
        endReasons = []
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        recorder = nil
        notificationCenter = nil
        try super.tearDownWithError()
    }

    func testStartRecordsForTheMaximumDurationIntoAWavFileNamedAfterTheSession() throws {
        let session = makeSession()

        XCTAssertEqual(try start(session), .success("session-1"))

        XCTAssertTrue(session.isRecording)
        XCTAssertEqual(recorder.recordedDuration, MicrophoneRecordingSession.maximumDuration)
        XCTAssertEqual(madeRecorderURLs, [fileURL])
    }

    func testADeniedMicrophoneFailsTheStart() throws {
        let session = makeSession(permissionGranted: false)

        XCTAssertEqual(try start(session), .failure(.microphoneDenied))

        XCTAssertFalse(session.isRecording)
        XCTAssertTrue(madeRecorderURLs.isEmpty)
    }

    func testAnAudioSessionThatCannotBePreparedFailsTheStart() throws {
        let session = makeSession(prepareAudioSession: { throw SetupError.failed })

        XCTAssertEqual(try start(session), .failure(.recordingFailed))
        XCTAssertTrue(madeRecorderURLs.isEmpty)
    }

    func testARecorderThatCannotBeMadeFailsTheStart() throws {
        let session = MicrophoneRecordingSession(
            sessionId: "session-1",
            directory: directory,
            notificationCenter: notificationCenter,
            requestMicrophonePermission: { true },
            prepareAudioSession: {},
            makeRecorder: { _ in throw SetupError.failed }
        )

        XCTAssertEqual(try start(session), .failure(.recordingFailed))
        XCTAssertFalse(session.isRecording)
    }

    func testARecorderThatDoesNotRecordFailsTheStart() throws {
        recorder.recordSucceeds = false
        let session = makeSession()

        XCTAssertEqual(try start(session), .failure(.recordingFailed))

        XCTAssertFalse(session.isRecording)
        XCTAssertNil(recorder.onFinish)
    }

    func testStartingTwiceAnswersTheSecondStartAsInterrupted() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))

        var second: Result<String, MicrophoneRecordingError>?
        session.start { second = $0 }

        XCTAssertEqual(second, .failure(.interrupted))
        XCTAssertTrue(session.isRecording)
    }

    func testStoppingWhileStartingAnswersTheStartAsInterruptedAndNeverRecords() throws {
        let session = makeSession()
        var outcome: Result<String, MicrophoneRecordingError>?
        session.start { outcome = $0 }

        session.stop()
        flushMainQueue()

        XCTAssertEqual(outcome, .failure(.interrupted))
        XCTAssertTrue(madeRecorderURLs.isEmpty)
    }

    func testStopEndsTheRecorderWithoutReportingAnEnd() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))

        session.stop()
        session.stop()

        XCTAssertFalse(session.isRecording)
        XCTAssertEqual(recorder.stopCount, 1)
        XCTAssertNil(recorder.onFinish)
        XCTAssertTrue(endReasons.isEmpty)
    }

    func testReachingTheMaximumDurationEndsTheRecording() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))

        recorder.finishOnItsOwn(successfully: true)

        XCTAssertEqual(endReasons, [.maxDuration])
        XCTAssertFalse(session.isRecording)
    }

    func testARecorderErrorEndsTheRecording() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))

        recorder.finishOnItsOwn(successfully: false)

        XCTAssertEqual(endReasons, [.failed])
    }

    func testAnAudioInterruptionEndsTheRecording() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))

        postInterruption(.ended)
        XCTAssertTrue(session.isRecording)

        postInterruption(.began)

        XCTAssertEqual(endReasons, [.interrupted])
        XCTAssertFalse(session.isRecording)
        XCTAssertEqual(recorder.stopCount, 1)

        postInterruption(.began)
        XCTAssertEqual(endReasons, [.interrupted])
    }

    func testFinishHandsOverTheRecordedWavAndDeletesIt() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))
        try writeWav(frames: 8000)
        let audio = try Data(contentsOf: fileURL)

        let result = try finish(session)

        XCTAssertEqual(recorder.stopCount, 1)
        let recording = try result.get()
        XCTAssertEqual(recording.sessionId, "session-1")
        XCTAssertEqual(recording.audio, audio)
        XCTAssertEqual(recording.sampleRate, 16000)
        XCTAssertEqual(recording.channels, 1)
        XCTAssertEqual(recording.duration, 0.5, accuracy: 0.001)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(endReasons.isEmpty)
    }

    func testFinishWithoutARecordedFileFails() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))

        XCTAssertEqual(try finish(session), .failure(.recordingFailed))
    }

    func testDiscardDeletesTheRecording() throws {
        let session = makeSession()
        XCTAssertEqual(try start(session), .success("session-1"))
        try writeWav(frames: 1600)

        session.discard()

        XCTAssertEqual(recorder.stopCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testThePayloadIsWhatTheFrontendReceives() {
        let recording = MicrophoneRecording(
            sessionId: "session-1",
            audio: Data([1, 2, 3]),
            sampleRate: 16000,
            channels: 1,
            duration: 1.5
        )

        let payload = recording.payload

        XCTAssertEqual(payload["session_id"] as? String, "session-1")
        XCTAssertEqual(payload["audio"] as? String, "AQID")
        XCTAssertEqual(payload["mime_type"] as? String, "audio/wav")
        XCTAssertEqual(payload["sample_rate"] as? Int, 16000)
        XCTAssertEqual(payload["channels"] as? Int, 1)
        XCTAssertEqual(payload["duration"] as? Double, 1.5)
    }

    // MARK: - Helpers

    private var fileURL: URL {
        directory.appendingPathComponent("microphone-recording-session-1.wav")
    }

    private func makeSession(
        permissionGranted: Bool = true,
        prepareAudioSession: @escaping () throws -> Void = {}
    ) -> MicrophoneRecordingSession {
        let recorder: FakeMicrophoneAudioRecorder = self.recorder
        let session = MicrophoneRecordingSession(
            sessionId: "session-1",
            directory: directory,
            notificationCenter: notificationCenter,
            requestMicrophonePermission: { permissionGranted },
            prepareAudioSession: prepareAudioSession,
            makeRecorder: { [weak self] url in
                self?.madeRecorderURLs.append(url)
                return recorder
            }
        )
        session.onEnd = { [weak self] reason in
            self?.endReasons.append(reason)
        }
        return session
    }

    private func start(_ session: MicrophoneRecordingSession) throws -> Result<String, MicrophoneRecordingError> {
        let answered = expectation(description: "start answered")
        var outcome: Result<String, MicrophoneRecordingError>?
        session.start {
            outcome = $0
            answered.fulfill()
        }
        wait(for: [answered], timeout: 5)
        return try XCTUnwrap(outcome)
    }

    private func finish(
        _ session: MicrophoneRecordingSession
    ) throws -> Result<MicrophoneRecording, MicrophoneRecordingError> {
        let finished = expectation(description: "finish answered")
        var outcome: Result<MicrophoneRecording, MicrophoneRecordingError>?
        session.finish {
            outcome = $0
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        return try XCTUnwrap(outcome)
    }

    /// Writes the WAV the recorder would have, the file is closed when it goes out of scope.
    private func writeWav(frames: AVAudioFrameCount) throws {
        let file = try AVAudioFile(
            forWriting: fileURL,
            settings: MicrophoneAudioRecorder.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
        buffer.frameLength = frames
        try file.write(from: buffer)
    }

    private func postInterruption(_ type: AVAudioSession.InterruptionType) {
        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: type.rawValue]
        )
        flushMainQueue()
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
    }
}
