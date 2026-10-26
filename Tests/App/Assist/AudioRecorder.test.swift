import AVFoundation
@testable import HomeAssistant
import Shared
import XCTest

final class AudioRecorderTests: XCTestCase {
    func testEmptyCaptureIsNotForwarded() throws {
        let recorder = AudioRecorder()
        let delegate = MockAudioRecorderDelegate()
        recorder.delegate = delegate
        _ = recorder.makeAudioOutput()

        try deliver(AssistAudioTestBuffers.makeUnformattedBuffer(frames: 0), to: recorder)

        XCTAssertTrue(delegate.output.isEmpty)
        XCTAssertTrue(delegate.errors.isEmpty)
    }

    func testRecorderForwardsConvertedMonoAtAdvertisedRate() throws {
        let recorder = AudioRecorder()
        let delegate = MockAudioRecorderDelegate()
        recorder.delegate = delegate
        _ = recorder.makeAudioOutput()
        let input = try AssistAudioTestBuffers.makeBuffer(rate: 48000, channels: 2, frames: 4800) { frame, channel in
            channel == 0 ? 0 : Float(sin(2 * .pi * 1000 * Double(frame) / 48000)) * 0.5
        }

        deliver(input, to: recorder)

        XCTAssertEqual(recorder.audioSampleRate, 16000)
        XCTAssertEqual(delegate.output.count, 1)
        let samples = try AssistAudioTestBuffers.samples(XCTUnwrap(delegate.output.first))
        XCTAssertEqual(samples.count, 1600, accuracy: 1)
        XCTAssertEqual(AssistAudioTestBuffers.positiveCrossings(samples), 100, accuracy: 1)
        XCTAssertTrue(delegate.errors.isEmpty)
    }

    func testRecorderStopsAfterConversionFailureAndRecoversForNextRecording() throws {
        let recorder = AudioRecorder()
        let delegate = MockAudioRecorderDelegate()
        recorder.delegate = delegate
        _ = recorder.makeAudioOutput()
        let stopped = expectation(description: "Conversion failure stops recording")
        delegate.stopped = { stopped.fulfill() }
        let invalid = try AssistAudioTestBuffers.makeBuffer(
            rate: 16000, channels: 2, frames: 1600, includeData: false
        ) { _, _ in 0 }
        let valid = try AssistAudioTestBuffers.makeBuffer(rate: 16000, channels: 1, frames: 1600) { _, _ in 0.25 }

        deliver(invalid, to: recorder)
        deliver(valid, to: recorder)
        wait(for: [stopped], timeout: 30)

        XCTAssertEqual(delegate.errors.count, 1)
        XCTAssertEqual(delegate.errors.first?.localizedDescription, L10n.Assist.Error.audioConversion)
        XCTAssertTrue(delegate.output.isEmpty)
        _ = recorder.makeAudioOutput()
        deliver(valid, to: recorder)
        XCTAssertEqual(delegate.output.count, 1)
        XCTAssertEqual(delegate.errors.count, 1)
    }

    func testAudioOutputDeliversOnSerialSampleQueueAtConvertedRate() {
        let recorder = AudioRecorder()

        let output = recorder.makeAudioOutput()

        XCTAssertTrue(output.sampleBufferDelegate === recorder)
        XCTAssertEqual(output.sampleBufferCallbackQueue?.label, "assist-audio-recorder-samples")
        XCTAssertEqual(recorder.audioSampleRate, 16000)
    }

    /// A setup that fails must not leave the previous recording's rate or session behind for this one.
    func testSetupWithoutMicrophoneReportsErrorAndClearsPreviousRecording() {
        let recorder = AudioRecorder(captureDevice: { nil })
        let delegate = MockAudioRecorderDelegate()
        recorder.delegate = delegate
        _ = recorder.makeAudioOutput()
        let failed = expectation(description: "Setup reports the missing microphone")
        delegate.failed = { _ in failed.fulfill() }

        recorder.startRecording()
        wait(for: [failed], timeout: 30)

        XCTAssertEqual(delegate.errors.first as? AudioRecorderError, .captureDeviceUnavailable)
        XCTAssertNil(recorder.audioSampleRate)
        XCTAssertTrue(delegate.startedSampleRates.isEmpty)
    }

    private func deliver(_ buffer: CMSampleBuffer, to recorder: AudioRecorder) {
        let output = AVCaptureAudioDataOutput()
        let connection = AVCaptureConnection(inputPorts: [], output: output)
        recorder.captureOutput(output, didOutput: buffer, from: connection)
    }
}
