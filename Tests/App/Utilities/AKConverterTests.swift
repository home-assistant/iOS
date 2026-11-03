import AVFoundation
import Foundation
@testable import HomeAssistant
import Testing

/// Converts generated audio files between the formats the notification sound importer accepts:
/// PCM to PCM (through CoreAudio), PCM to AAC (through AVAssetWriter) and AAC to AAC (through an
/// export session), plus the argument errors each path reports.
///
/// Each test converts in a fresh directory of its own under the temporary directory, which the system
/// purges; the files are a few kilobytes.
struct AKConverterTests {
    // MARK: - Helpers

    private final class Completion: @unchecked Sendable {
        private let lock = NSLock()
        private var _done = false
        private var _error: Error?

        var done: Bool { lock.withLock { _done } }
        var error: Error? { lock.withLock { _error } }

        func finish(_ error: Error?) {
            lock.withLock {
                guard !_done else { return }
                _done = true
                _error = error
            }
        }
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AKConverterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a short sine tone as 16-bit PCM in the container the extension names.
    private func makePCMFile(
        at url: URL,
        sampleRate: Double = 44100,
        channels: AVAudioChannelCount = 1,
        bigEndian: Bool = false
    ) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: bigEndian,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let frames: AVAudioFrameCount = 4410
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
        buffer.frameLength = frames
        let channelData = try #require(buffer.floatChannelData)
        for channel in 0 ..< Int(file.processingFormat.channelCount) {
            for frame in 0 ..< Int(frames) {
                channelData[channel][frame] = sin(Float(frame) * 0.05) * 0.5
            }
        }
        try file.write(from: buffer)
    }

    /// Starts the conversion and polls (at most ten seconds) for its completion handler.
    private func convert(
        _ input: URL,
        to output: URL,
        options: AKConverter.Options? = nil,
        configure: (AKConverter) -> Void = { _ in }
    ) async -> (finished: Bool, error: Error?) {
        let converter = AKConverter(inputURL: input, outputURL: output, options: options)
        configure(converter)
        let completion = Completion()
        converter.start { completion.finish($0) }
        let deadline = Date().addingTimeInterval(10)
        while !completion.done, Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return (completion.done, completion.error)
    }

    private func message(_ error: Error?) -> String? {
        (error as NSError?)?.localizedDescription
    }

    private func fileSize(_ url: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
    }

    // MARK: - Options and arguments

    @Test func bitRateIsClampedToTheMinimum() {
        var options = AKConverter.Options()
        options.bitRate = 32000
        #expect(options.bitRate == 64000)
        options.bitRate = 256_000
        #expect(options.bitRate == 256_000)
        #expect(options.eraseFile)
        #expect(AKConverter.inputFormats.contains("mp3"))
        #expect(AKConverter.outputFormats == ["wav", "aif", "caf", "m4a"])
    }

    @Test func missingURLsAndUnknownInputFormatsFail() async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.wav")
        let output = directory.appendingPathComponent("out.wav")

        let noInput = await convert(input, to: output) { $0.inputURL = nil }
        #expect(noInput.finished)
        #expect(message(noInput.error) == "Input file can't be nil.")

        let noOutput = await convert(input, to: output) { $0.outputURL = nil }
        #expect(message(noOutput.error) == "Output file can't be nil.")

        let unknown = await convert(directory.appendingPathComponent("in.txt"), to: output)
        #expect(message(unknown.error) == "The input file format isn't able to be processed.")

        let missing = await convert(input, to: output)
        #expect(message(missing.error) == "Unable to open the input file.")
    }

    // MARK: - PCM output

    @Test(arguments: ["aif", "caf", "wav"])
    func convertsPCMToEachPCMContainer(_ outputExtension: String) async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.wav")
        try makePCMFile(at: input, sampleRate: 22050)
        let output = directory.appendingPathComponent("out.\(outputExtension)")

        var options = AKConverter.Options()
        options.sampleRate = 44100
        options.channels = 2
        options.bitDepth = 16
        let result = await convert(input, to: output, options: options)

        #expect(result.finished)
        #expect(result.error == nil)
        #expect(fileSize(output) > 0)
        let converted = try AVAudioFile(forReading: output)
        #expect(converted.fileFormat.sampleRate == 44100)
        #expect(converted.fileFormat.channelCount == 2)
    }

    @Test func aFileAlreadyInTheRequestedFormatIsCopied() async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.wav")
        try makePCMFile(at: input)
        let output = directory.appendingPathComponent("out.wav")

        let result = await convert(input, to: output)

        #expect(result.error == nil)
        #expect(fileSize(output) == fileSize(input))
    }

    @Test func anUnsupportedPCMFormatOptionFails() async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.wav")
        try makePCMFile(at: input)

        var options = AKConverter.Options()
        options.format = "flac"
        let result = await convert(input, to: directory.appendingPathComponent("out.wav"), options: options)

        #expect(message(result.error) == "Output file must be caf, wav or aif.")
    }

    // MARK: - Compressed output

    @Test func convertsPCMToAACAndBackAndBetweenAACFiles() async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.aif")
        try makePCMFile(at: input, sampleRate: 96000, channels: 2, bigEndian: true)

        // PCM in, AAC out: AVAssetWriter, with the sample rate capped for AAC.
        let aac = directory.appendingPathComponent("tone.m4a")
        var options = AKConverter.Options()
        options.sampleRate = 96000
        let encoded = await convert(input, to: aac, options: options)
        #expect(encoded.finished)
        #expect(encoded.error == nil)
        #expect(fileSize(aac) > 0)

        // AAC in, PCM out: CoreAudio decodes the compressed source (no bit depth of its own).
        let decoded = directory.appendingPathComponent("decoded.wav")
        let decode = await convert(aac, to: decoded)
        #expect(decode.finished)
        #expect(decode.error == nil)
        #expect(fileSize(decoded) > 0)

        // AAC in, AAC out: an export session with the default preset.
        let reexported = directory.appendingPathComponent("again.m4a")
        let export = await convert(aac, to: reexported)
        #expect(export.finished)
        #expect(export.error == nil)
    }

    @Test(arguments: ["wav", "caf", "aif"])
    func writesPCMThroughTheAssetWriterWhenTheFormatOptionAsksForIt(_ format: String) async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.wav")
        try makePCMFile(at: input)

        // An existing output is replaced when `eraseFile` is on (the default).
        let output = directory.appendingPathComponent("out.m4a")
        try Data("stale".utf8).write(to: output)

        var options = AKConverter.Options()
        options.format = format
        options.bitDepth = 16
        options.isInterleaved = true
        let result = await convert(input, to: output, options: options)

        #expect(result.finished)
        #expect(result.error == nil)
        // The stale bytes are gone: the output reopens as the input's 16-bit PCM tone, in full.
        let converted = try AVAudioFile(forReading: output)
        let description = converted.fileFormat.streamDescription.pointee
        #expect(description.mFormatID == kAudioFormatLinearPCM)
        #expect(description.mBitsPerChannel == 16)
        #expect(converted.fileFormat.sampleRate == 44100)
        #expect(converted.fileFormat.channelCount == 1)
        #expect(converted.length == 4410)
    }

    @Test func assetWriterErrorsAreReported() async throws {
        let directory = try makeDirectory()
        let input = directory.appendingPathComponent("in.wav")
        try makePCMFile(at: input)
        let output = directory.appendingPathComponent("out.m4a")

        var unsupported = AKConverter.Options()
        unsupported.format = "flac"
        let badFormat = await convert(input, to: output, options: unsupported)
        #expect(message(badFormat.error) == "The output file format isn't able to be produced by this class.")

        try Data("existing".utf8).write(to: output)
        var keep = AKConverter.Options()
        keep.eraseFile = false
        let exists = await convert(input, to: output, options: keep)
        #expect(message(exists.error)?.contains("exists already") == true)

        let missing = await convert(directory.appendingPathComponent("missing.wav"), to: output)
        #expect(missing.finished)
        #expect(missing.error != nil)
    }
}
