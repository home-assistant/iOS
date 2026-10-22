import AVFoundation
@testable import HomeAssistant
import Shared
import XCTest

final class AudioRecorderTests: XCTestCase {
    func testEmptyCaptureIsNotForwarded() throws {
        let recorder = AudioRecorder()
        let delegate = MockAudioRecorderDelegate()
        recorder.delegate = delegate
        recorder.prepareAudioConversion()

        try deliver(AssistAudioTestBuffers.makeUnformattedBuffer(frames: 0), to: recorder)

        XCTAssertTrue(delegate.output.isEmpty)
        XCTAssertTrue(delegate.errors.isEmpty)
    }

    func testRecorderForwardsConvertedMonoAtAdvertisedRate() throws {
        let recorder = AudioRecorder()
        let delegate = MockAudioRecorderDelegate()
        recorder.delegate = delegate
        recorder.prepareAudioConversion()
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
        recorder.prepareAudioConversion()
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
        recorder.prepareAudioConversion()
        deliver(valid, to: recorder)
        XCTAssertEqual(delegate.output.count, 1)
        XCTAssertEqual(delegate.errors.count, 1)
    }

    private func deliver(_ buffer: CMSampleBuffer, to recorder: AudioRecorder) {
        let output = AVCaptureAudioDataOutput()
        let connection = AVCaptureConnection(inputPorts: [], output: output)
        recorder.captureOutput(output, didOutput: buffer, from: connection)
    }
}
