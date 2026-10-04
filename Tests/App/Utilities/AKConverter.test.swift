import AVFoundation
@testable import HomeAssistant
import XCTest

/// `AKConverter` turns a sound picked by the user into the 48 kHz, 32-bit WAV that notification sounds
/// are stored as. These tests write a short tone to disk and convert it through each of its paths.
final class AKConverterTests: XCTestCase {
    private var directory: URL!

    private let inputSampleRate: Double = 44100
    private let inputFrameCount: AVAudioFrameCount = 11025

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AKConverterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testBitRateIsClampedToItsMinimum() {
        var options = AKConverter.Options()
        XCTAssertEqual(options.bitRate, 128_000)
        options.bitRate = 1000
        XCTAssertEqual(options.bitRate, 64000)
        options.bitRate = 96000
        XCTAssertEqual(options.bitRate, 96000)
        XCTAssertTrue(options.eraseFile)
        XCTAssertNil(options.format)
    }

    func testSupportedFormats() {
        XCTAssertEqual(AKConverter.outputFormats, ["wav", "aif", "caf", "m4a"])
        XCTAssertTrue(AKConverter.inputFormats.contains("mp3"))
        XCTAssertTrue(AKConverter.inputFormats.contains(""))
        XCTAssertTrue(AKConverter.outputFormats.allSatisfy { AKConverter.inputFormats.contains($0) })
    }

    func testFailsWithoutAnInputURL() {
        let converter = AKConverter(inputURL: url("in.wav"), outputURL: url("out.wav"))
        converter.inputURL = nil

        XCTAssertEqual(convert(converter)?.localizedDescription, "Input file can't be nil.")
    }

    func testFailsWithoutAnOutputURL() {
        let converter = AKConverter(inputURL: url("in.wav"), outputURL: url("out.wav"))
        converter.outputURL = nil

        XCTAssertEqual(convert(converter)?.localizedDescription, "Output file can't be nil.")
    }

    func testRejectsAnUnsupportedInputFormat() {
        let converter = AKConverter(inputURL: url("in.txt"), outputURL: url("out.wav"))

        let error = convert(converter) as NSError?
        XCTAssertEqual(error?.localizedDescription, "The input file format isn't able to be processed.")
        XCTAssertEqual(error?.domain, "io.audiokit.AKConverter.error")
        XCTAssertEqual(error?.code, 1)
    }

    func testRejectsAPCMOutputFormatItCannotWrite() throws {
        let input = try makeWAV(named: "in.wav")
        var options = AKConverter.Options()
        options.format = "m4a"
        let converter = AKConverter(inputURL: input, outputURL: url("out.wav"), options: options)

        XCTAssertEqual(convert(converter)?.localizedDescription, "Output file must be caf, wav or aif.")
    }

    func testFailsWhenThePCMInputCannotBeOpened() {
        let converter = AKConverter(inputURL: url("missing.wav"), outputURL: url("out.caf"))

        XCTAssertEqual(convert(converter)?.localizedDescription, "Unable to open the input file.")
    }

    func testCopiesAFileThatIsAlreadyInTheRequestedFormat() throws {
        let input = try makeWAV(named: "in.wav")
        let output = url("out.wav")

        XCTAssertNil(convert(AKConverter(inputURL: input, outputURL: output)))
        XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: input))
    }

    func testConvertsWAVToCAF() throws {
        let input = try makeWAV(named: "in.wav")
        let output = url("out.caf")

        XCTAssertNil(convert(AKConverter(inputURL: input, outputURL: output)))

        let file = try AVAudioFile(forReading: output)
        XCTAssertEqual(file.fileFormat.sampleRate, inputSampleRate)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(file.length, AVAudioFramePosition(inputFrameCount))
    }

    /// The conversion notification sounds go through when the user imports one.
    func testConvertsToTheNotificationSoundFormat() throws {
        let input = try makeWAV(named: "in.wav")
        let output = url("sound.wav")
        var options = AKConverter.Options()
        options.format = "wav"
        options.sampleRate = 48000
        options.bitDepth = 32
        options.eraseFile = true

        XCTAssertNil(convert(AKConverter(inputURL: input, outputURL: output, options: options)))

        let file = try AVAudioFile(forReading: output)
        XCTAssertEqual(file.fileFormat.sampleRate, 48000)
        XCTAssertEqual(file.fileFormat.settings[AVLinearPCMBitDepthKey] as? Int, 32)
        XCTAssertGreaterThan(file.length, 0)
    }

    func testRejectsACompressedOutputFormatItCannotWrite() throws {
        let input = try makeWAV(named: "in.wav")
        var options = AKConverter.Options()
        options.format = "mp3"
        let converter = AKConverter(inputURL: input, outputURL: url("out.m4a"), options: options)

        XCTAssertEqual(
            convert(converter)?.localizedDescription,
            "The output file format isn't able to be produced by this class."
        )
    }

    func testRefusesToOverwriteWhenErasingIsDisabled() throws {
        let input = try makeWAV(named: "in.wav")
        let output = url("out.m4a")
        try Data([1, 2, 3]).write(to: output)
        var options = AKConverter.Options()
        options.eraseFile = false
        let converter = AKConverter(inputURL: input, outputURL: output, options: options)

        XCTAssertEqual(
            convert(converter)?.localizedDescription,
            "The output file exists already. You need to choose a unique URL or delete the file."
        )
        XCTAssertEqual(try Data(contentsOf: output), Data([1, 2, 3]))
    }

    func testFailsWhenTheCompressedOutputsInputCannotBeRead() {
        let converter = AKConverter(inputURL: url("missing.wav"), outputURL: url("out.m4a"))

        XCTAssertNotNil(convert(converter))
    }

    func testEncodesPCMToAAC() throws {
        let input = try makeWAV(named: "in.wav")
        let output = url("out.m4a")

        XCTAssertNil(convert(AKConverter(inputURL: input, outputURL: output)))

        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        XCTAssertGreaterThan((attributes[.size] as? NSNumber)?.intValue ?? 0, 0)
    }

    func testReExportsCompressedAudio() throws {
        let input = try makeWAV(named: "in.wav")
        let compressed = url("first.m4a")
        XCTAssertNil(convert(AKConverter(inputURL: input, outputURL: compressed)))

        let output = url("second.m4a")
        XCTAssertNil(convert(AKConverter(inputURL: compressed, outputURL: output)))
    }

    // MARK: - Helpers

    private func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Runs the conversion and returns the error it finished with, or nil on success.
    private func convert(_ converter: AKConverter) -> Error? {
        let finished = expectation(description: "conversion finished")
        var result: Error?
        converter.start { error in
            result = error
            finished.fulfill()
        }
        wait(for: [finished], timeout: 30)
        return result
    }

    /// A quarter of a second of a 16-bit mono tone.
    private func makeWAV(named name: String) throws -> URL {
        let output = url(name)
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: inputSampleRate,
            channels: 1,
            interleaved: true
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: inputFrameCount))
        buffer.frameLength = inputFrameCount
        let samples = try XCTUnwrap(buffer.int16ChannelData)[0]
        for frame in 0 ..< Int(inputFrameCount) {
            samples[frame] = Int16(sin(Double(frame) * 0.05) * 8000)
        }

        // Scoped so the file is closed, and its header finalized, before it is converted.
        do {
            let file = try AVAudioFile(
                forWriting: output,
                settings: format.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
            try file.write(from: buffer)
        }
        return output
    }
}
