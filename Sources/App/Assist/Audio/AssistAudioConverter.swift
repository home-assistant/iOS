import AVFoundation
import Shared

/// Converts capture buffers to the PCM format accepted by the Assist websocket API.
/// Use one instance per recording, on the sample buffer delegate's serial queue.
final class AssistAudioConverter {
    static let sampleRate: Double = 16000
    /// Output is produced in chunks of this size, so one capture buffer may take several passes.
    private static let outputFrameCapacity: AVAudioFrameCount = 1024

    private enum ConversionError: LocalizedError {
        case invalidInput
        case cannotCreateBuffer
        case cannotCreateConverter
        case cannotCopySamples(OSStatus)
        case conversionFailed(Error?)

        var errorDescription: String? {
            L10n.Assist.Error.audioConversion
        }
    }

    private var converter: AVAudioConverter?

    private func inputFormat(_ sampleBuffer: CMSampleBuffer) throws -> AVAudioFormat? {
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return nil }
        guard frameCount <= Int(Int32.max),
              let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              CMFormatDescriptionGetMediaSubType(description) == kAudioFormatLinearPCM else {
            throw ConversionError.invalidInput
        }

        let inputFormat = AVAudioFormat(cmAudioFormatDescription: description)
        guard inputFormat.sampleRate.isFinite, inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw ConversionError.invalidInput
        }
        return inputFormat
    }

    private func inputBuffer(
        _ sampleBuffer: CMSampleBuffer, format: AVAudioFormat, offset: Int, frames: Int
    ) throws -> AVAudioPCMBuffer {
        guard let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
            throw ConversionError.cannotCreateBuffer
        }
        input.frameLength = input.frameCapacity
        let copyStatus = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: Int32(offset),
            frameCount: Int32(frames),
            into: input.mutableAudioBufferList
        )
        guard copyStatus == noErr else { throw ConversionError.cannotCopySamples(copyStatus) }
        return input
    }

    private func converter(for inputFormat: AVAudioFormat) throws -> AVAudioConverter {
        if converter?.inputFormat != inputFormat {
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Self.sampleRate,
                channels: 1,
                interleaved: true
            ), let newConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                throw ConversionError.cannotCreateConverter
            }
            newConverter.downmix = true
            newConverter.primeMethod = .none
            Current.Log.info("Converting Assist audio from \(inputFormat) to \(outputFormat)")
            converter = newConverter
        }
        guard let converter else { throw ConversionError.cannotCreateConverter }
        return converter
    }

    func convert(_ sampleBuffer: CMSampleBuffer) throws -> Data {
        guard let format = try inputFormat(sampleBuffer) else { return Data() }
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        // Keep the converter across callbacks so resampling preserves its fractional frame position.
        let converter = try converter(for: format)
        guard let output = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: Self.outputFrameCapacity
        ) else {
            throw ConversionError.cannotCreateBuffer
        }
        var suppliedFrames = 0
        var inputError: Error?
        var data = Data()
        while true {
            output.frameLength = 0
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { requestedFrames, inputStatus in
                guard suppliedFrames < frameCount, inputError == nil else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                // Supply only what is requested. Oversized buffers can leave a tail queued
                // inside the converter that is not emitted when recording stops.
                let frames = min(Int(requestedFrames), frameCount - suppliedFrames)
                do {
                    let input = try self.inputBuffer(
                        sampleBuffer,
                        format: format,
                        offset: suppliedFrames,
                        frames: frames
                    )
                    suppliedFrames += frames
                    inputStatus.pointee = .haveData
                    return input
                } catch {
                    inputError = error
                    inputStatus.pointee = .noDataNow
                    return nil
                }
            }
            if let inputError { throw inputError }
            if let error { throw ConversionError.conversionFailed(error) }
            guard status != .error else { throw ConversionError.conversionFailed(nil) }
            if output.frameLength > 0, let samples = output.int16ChannelData {
                data.append(
                    UnsafeRawPointer(samples[0]).assumingMemoryBound(to: UInt8.self),
                    count: Int(output.frameLength) * 2
                )
            }
            // A full output chunk means the converter may still hold more of this buffer.
            if status != .haveData { return data }
        }
    }
}
