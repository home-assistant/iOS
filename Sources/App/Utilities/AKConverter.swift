//
//  AKConverter.swift
//  AudioKit
//
//  Created by Ryan Francesconi, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//  From https://bit.ly/2Uw4wGZ
//
//  Mods to this file:
//  - replacing AKLog with Current.Log.*
//  - disabling SwiftLint
//  - allowing already-correct-format to not fail (see // HASS below)
//
// swiftlint:disable all
// swiftformat:disable all

import Foundation
import AVFoundation
import CoreAudio
import Shared

/**
 AKConverter wraps the more complex AVFoundation and CoreAudio audio conversions in an easy to use format.
 ```
 let options = AKConverter.Options()
 // any options left nil will assume the value of the input file
 options.format = "wav"
 options.sampleRate == 48000
 options.bitDepth = 24

 let converter = AKConverter(inputURL: oldURL, outputURL: newURL, options: options)
 converter.start(completionHandler: { error in
 // check to see if error isn't nil, otherwise you're good
 })
 ```
 */

open class AKConverter: NSObject {
    /**
     AKConverterCallback is the callback format for start()
     -Parameter: error This will contain one parameter of type Error which is nil if the conversion was successful.
     */
    public typealias AKConverterCallback = (_ error: Error?) -> Void

    /** Formats that this class can write */
    public static let outputFormats = ["wav", "aif", "caf", "m4a"]

    /** Formats that this class can read */
    public static let inputFormats = AKConverter.outputFormats + [
        "mp3",
        "snd",
        "au",
        "sd2",
        "aiff",
        "aifc",
        "aac",
        "mp4",
        "m4v",
        "mov",
        "" // allow files with no extension. convertToPCM can still read the type
    ]

    /// The conversion options, leave nil to adopt the value of the input file
    public struct Options {
        public init() {}
        public var format: String?
        public var sampleRate: Double?
        /// used only with PCM data
        public var bitDepth: UInt32?
        /// used only when outputting compressed from PCM - convertAsset()
        public var bitRate: UInt32 = 128_000 {
            didSet {
                if bitRate < 64_000 {
                    bitRate = 64_000
                }
            }
        }

        public var channels: UInt32?
        public var isInterleaved: Bool?
        /// overwrite existing files, set false if you want to handle this before you call start()
        public var eraseFile: Bool = true
    }

    // MARK: - public properties

    open var inputURL: URL?
    open var outputURL: URL?
    open var options: Options?

    // MARK: - private properties

    // The reader needs to exist outside the start func otherwise the async nature of the
    // AVAssetWriterInput will lose its reference
    private var reader: AVAssetReader?

    // MARK: - initialization

    /// init with input, output and options - then start()
    public init(inputURL: URL, outputURL: URL, options: Options? = nil) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.options = options
    }

    // MARK: - public functions

    /**
     The entry point for file conversion

     - Parameter completionHandler: the callback that will be triggered when process has completed.
     */
    open func start(completionHandler: AKConverterCallback? = nil) {
        guard let inputURL = self.inputURL else {
            completionHandler?(createError(message: "Input file can't be nil."))
            return
        }

        guard let outputURL = self.outputURL else {
            completionHandler?(createError(message: "Output file can't be nil."))
            return
        }

        let inputFormat = inputURL.pathExtension.lowercased()
        // verify inputFormat
        guard AKConverter.inputFormats.contains(inputFormat) else {
            completionHandler?(createError(message: "The input file format isn't able to be processed."))
            return
        }

        // Format checks are necessary as AVAssetReader has opinions about compressed audio for some reason
        if isCompressed(url: inputURL), isCompressed(url: outputURL) {
            // Compressed input and output
            convertCompressed(completionHandler: completionHandler)

        } else if !isCompressed(url: outputURL) {
            // PCM output
            convertToPCM(completionHandler: completionHandler)

        } else {
            // PCM input, compressed output
            convertAsset(completionHandler: completionHandler)
        }
    }

    // MARK: - private helper functions

    // The AVFoundation way. This method doesn't handle compressed input - only compressed output.
    private func convertAsset(completionHandler: AKConverterCallback? = nil) {
        guard let inputURL = self.inputURL else {
            completionHandler?(createError(message: "Input file can't be nil."))
            return
        }
        guard let outputURL = self.outputURL else {
            completionHandler?(createError(message: "Output file can't be nil."))
            return
        }

        let outputFormat = options?.format ?? outputURL.pathExtension.lowercased()

        Current.Log.info("Converting Asset to \(outputFormat)")

        // verify outputFormat
        guard AKConverter.outputFormats.contains(outputFormat) else {
            completionHandler?(createError(message: "The output file format isn't able to be produced by this class."))
            return
        }

        let asset = AVAsset(url: inputURL)
        do {
            reader = try AVAssetReader(asset: asset)

        } catch let err as NSError {
            completionHandler?(err)
            return
        }

        guard let reader = reader else {
            completionHandler?(createError(message: "Unable to setup the AVAssetReader."))
            return
        }

        var inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: inputURL)
        } catch let err as NSError {
            // Error creating input audio file
            completionHandler?(err)
            return
        }

        if options == nil {
            options = Options()
        }

        guard let options = options else {
            completionHandler?(createError(message: "The options are malformed."))
            return
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            if options.eraseFile {
                Current.Log.warning("Warning: removing existing file at \(outputURL.path)")
                try? FileManager.default.removeItem(at: outputURL)
            } else {
                let message = "The output file exists already. You need to choose a unique URL or delete the file."
                let err = createError(message: message)
                completionHandler?(err)
                return
            }
        }

        var format: AVFileType
        var formatKey: AudioFormatID

        switch outputFormat {
        case "m4a", "mp4":
            format = .m4a
            formatKey = kAudioFormatMPEG4AAC
        case "aif":
            format = .aiff
            formatKey = kAudioFormatLinearPCM
        case "caf":
            format = .caf
            formatKey = kAudioFormatLinearPCM
        case "wav":
            format = .wav
            formatKey = kAudioFormatLinearPCM
        default:
            Current.Log.error("Unsupported output format: \(outputFormat)")
            return
        }

        var writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: format)
        } catch let err as NSError {
            completionHandler?(err)
            return
        }

        // 1. chosen option. 2. same as input file. 3. 16 bit
        // optional in case of compressed audio. That said, the other conversion methods are actually used in
        // that case
        let bitDepth = (options.bitDepth ?? inputFile.fileFormat.settings[AVLinearPCMBitDepthKey] ?? 16) as Any
        var isFloat = false
        if let intDepth = bitDepth as? Int {
            // 32 bit means it's floating point
            isFloat = intDepth == 32
        }

        var sampleRate = options.sampleRate ?? inputFile.fileFormat.sampleRate
        let channels = options.channels ?? inputFile.fileFormat.channelCount

        var outputSettings: [String: Any] = [
            AVFormatIDKey: formatKey,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: isFloat,
            AVLinearPCMIsBigEndianKey: format != .wav,
            AVLinearPCMIsNonInterleaved: !(options.isInterleaved ?? inputFile.fileFormat.isInterleaved)
        ]

        // Note: AVAssetReaderOutput does not currently support compressed audio?
        if formatKey == kAudioFormatMPEG4AAC {
            if sampleRate > 48_000 {
                sampleRate = 48_000
            }
            // reset these for m4a:
            outputSettings = [
                AVFormatIDKey: formatKey,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: Int(options.bitRate),
                AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Constant
            ]
        }

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writer.add(writerInput)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            completionHandler?(createError(message: "No audio was found in the input file."))
            return
        }

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(readerOutput) else {
            completionHandler?(createError(message: "Unable to add reader output."))
            return
        }
        reader.add(readerOutput)

        if !writer.startWriting() {
            Current.Log.error("Failed to start writing. " + (writer.error?.localizedDescription ?? ""))
            completionHandler?(writer.error)
            return
        }

        writer.startSession(atSourceTime: CMTime.zero)

        if !reader.startReading() {
            Current.Log.error("Failed to start reading. " + (reader.error?.localizedDescription ?? ""))
            completionHandler?(reader.error)
            return
        }

        let queue = DispatchQueue(label: "io.audiokit.AKConverter.convertAsset")

        // session.progress could be sent out via a delegate for this session
        writerInput.requestMediaDataWhenReady(on: queue, using: {
            var processing = true // safety flag to prevent runaway loops if errors

            while writerInput.isReadyForMoreMediaData, processing {
                if reader.status == .reading,
                    let buffer = readerOutput.copyNextSampleBuffer() {
                    writerInput.append(buffer)

                } else {
                    writerInput.markAsFinished()

                    switch reader.status {
                    case .failed:
                        Current.Log.error("Conversion failed with error" + (reader.error?.localizedDescription ?? "Unknown"))
                        writer.cancelWriting()
                        completionHandler?(reader.error)
                    case .cancelled:
                        Current.Log.info("Conversion cancelled")
                        completionHandler?(nil)
                    case .completed:
                        writer.finishWriting {
                            switch writer.status {
                            case .failed:
                                completionHandler?(writer.error)
                            default:
                                completionHandler?(nil)
                            }
                        }
                    default:
                        break
                    }
                    processing = false
                }
            }
        }) // requestMediaDataWhenReady
    }

    // Example of the most simplistic AVFoundation conversion.
    // With this approach you can't really specify any settings other than the limited presets.
    private func convertCompressed(completionHandler: AKConverterCallback? = nil) {
        guard let inputURL = self.inputURL else {
            completionHandler?(createError(message: "Input file can't be nil."))
            return
        }
        guard let outputURL = self.outputURL else {
            completionHandler?(createError(message: "Output file can't be nil."))
            return
        }

        let asset = AVURLAsset(url: inputURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { return }

        Current.Log.info("Converting to AVAssetExportPresetAppleM4A with default settings.")

        // session.progress could be sent out via a delegate for this session
        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.exportAsynchronously {
            completionHandler?(nil)
        }
    }

    // Currently, as of 2017, if you want to convert from a compressed
    // format to a pcm one, you still have to hit CoreAudio
    private func convertToPCM(completionHandler: AKConverterCallback? = nil) {
        guard let inputURL = self.inputURL else {
            completionHandler?(createError(message: "Input file can't be nil."))
            return
        }
        guard let outputURL = self.outputURL else {
            completionHandler?(createError(message: "Output file can't be nil."))
            return
        }

        if isCompressed(url: outputURL) {
            completionHandler?(createError(message: "Output file must be PCM."))
            return
        }

        let inputFormat = inputURL.pathExtension.lowercased()
        let outputFormat = options?.format ?? outputURL.pathExtension.lowercased()

        Current.Log.info("convertToPCM() to \(outputURL)")

        var format: AudioFileTypeID
        let formatKey: AudioFormatID = kAudioFormatLinearPCM

        switch outputFormat {
        case "aif":
            format = kAudioFileAIFFType
        case "wav":
            format = kAudioFileWAVEType
        case "caf":
            format = kAudioFileCAFType
        default:
            completionHandler?(createError(message: "Output file must be caf, wav or aif."))
            return
        }

        var error = noErr
        var destinationFile: ExtAudioFileRef?
        var sourceFile: ExtAudioFileRef?

        var srcFormat = AudioStreamBasicDescription()
        var dstFormat = AudioStreamBasicDescription()

        error = ExtAudioFileOpenURL(inputURL as CFURL, &sourceFile)
        if error != noErr {
            completionHandler?(createError(message: "Unable to open the input file."))
            return
        }

        var thePropertySize = UInt32(MemoryLayout.stride(ofValue: srcFormat))

        guard let inputFile = sourceFile else {
            completionHandler?(createError(message: "Unable to open the input file."))
            return
        }

        error = ExtAudioFileGetProperty(inputFile,
                                        kExtAudioFileProperty_FileDataFormat,
                                        &thePropertySize, &srcFormat)

        if error != noErr {
            completionHandler?(createError(message: "Unable to get the input file data format."))
            return
        }
        let outputSampleRate = options?.sampleRate ?? srcFormat.mSampleRate
        let outputChannels = options?.channels ?? srcFormat.mChannelsPerFrame
        var outputBitRate = options?.bitDepth ?? srcFormat.mBitsPerChannel

        guard inputFormat != outputFormat ||
            outputSampleRate != srcFormat.mSampleRate ||
            outputChannels != srcFormat.mChannelsPerFrame ||
            outputBitRate != srcFormat.mBitsPerChannel else {
            // HASS
            _ = try? FileManager.default.copyItem(at: inputURL, to: outputURL)
            completionHandler?(nil)
            // HASS
            return
        }

        var outputBytesPerFrame = outputBitRate * outputChannels / 8
        var outputBytesPerPacket = options?.bitDepth == nil ? srcFormat.mBytesPerPacket : outputBytesPerFrame

        // in the input file this indicates a compressed format such as mp3
        if outputBitRate == 0 {
            outputBitRate = 16
            outputBytesPerPacket = 2 * outputChannels
            outputBytesPerFrame = 2 * outputChannels
        }

        dstFormat.mSampleRate = outputSampleRate
        dstFormat.mFormatID = formatKey
        dstFormat.mChannelsPerFrame = outputChannels
        dstFormat.mBitsPerChannel = outputBitRate
        dstFormat.mBytesPerPacket = outputBytesPerPacket
        dstFormat.mBytesPerFrame = outputBytesPerFrame
        dstFormat.mFramesPerPacket = 1
        dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger

        if format == kAudioFileAIFFType {
            dstFormat.mFormatFlags = dstFormat.mFormatFlags | kLinearPCMFormatFlagIsBigEndian
        }

        // Create destination file
        error = ExtAudioFileCreateWithURL(outputURL as CFURL,
                                          format,
                                          &dstFormat,
                                          nil,
                                          AudioFileFlags.eraseFile.rawValue, // overwrite old file if present
                                          &destinationFile)

        if error != noErr {
            completionHandler?(createError(message: "Unable to create output file."))
            return
        }

        guard let outputFile = destinationFile else {
            completionHandler?(createError(message: "Unable to create output file (2)."))
            return
        }

        error = ExtAudioFileSetProperty(inputFile,
                                        kExtAudioFileProperty_ClientDataFormat,
                                        thePropertySize,
                                        &dstFormat)
        if error != noErr {
            completionHandler?(createError(message: "Unable to set data format on output file."))
            return
        }

        error = ExtAudioFileSetProperty(outputFile,
                                        kExtAudioFileProperty_ClientDataFormat,
                                        thePropertySize,
                                        &dstFormat)
        if error != noErr {
            completionHandler?(createError(message: "Unable to set the output file data format."))
            return
        }
        let bufferByteSize: UInt32 = 32_768
        var srcBuffer = [UInt8](repeating: 0, count: Int(bufferByteSize))
        var sourceFrameOffset: UInt32 = 0

        srcBuffer.withUnsafeMutableBytes { ptr in
            while true {
                let mBuffer = AudioBuffer(mNumberChannels: srcFormat.mChannelsPerFrame,
                                          mDataByteSize: bufferByteSize,
                                          mData: ptr.baseAddress)

                var fillBufList = AudioBufferList(mNumberBuffers: 1, mBuffers: mBuffer)
                var numFrames: UInt32 = 0

                if dstFormat.mBytesPerFrame > 0 {
                    numFrames = bufferByteSize / dstFormat.mBytesPerFrame
                }

                error = ExtAudioFileRead(inputFile, &numFrames, &fillBufList)
                if error != noErr {
                    completionHandler?(createError(message: "Unable to read input file."))
                    return
                }
                if numFrames == 0 {
                    error = noErr
                    break
                }

                sourceFrameOffset += numFrames

                error = ExtAudioFileWrite(outputFile, numFrames, &fillBufList)
                if error != noErr {
                    completionHandler?(createError(message: "Unable to write output file."))
                    return
                }
            }
        }

        error = ExtAudioFileDispose(outputFile)
        if error != noErr {
            completionHandler?(createError(message: "Unable to dispose the output file object."))
            return
        }

        error = ExtAudioFileDispose(inputFile)
        if error != noErr {
            completionHandler?(createError(message: "Unable to dispose the input file object."))
            return
        }

        completionHandler?(nil)
    }

    private func isCompressed(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return (ext == "m4a" || ext == "mp3" || ext == "mp4" || ext == "m4v" || ext == "mpg")
    }

    private func createError(message: String, code: Int = 1) -> NSError {
        let userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
        return NSError(domain: "io.audiokit.AKConverter.error", code: code, userInfo: userInfo)
    }
}
