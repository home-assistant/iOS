import Speech
import AVFoundation
import Speech

import Foundation
import Speech
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class SpokenWordTranscriber {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var transcriber: SpeechTranscriber?
    private var detector: SpeechDetector!
    private var analyzer: SpeechAnalyzer?
    private var recognizerTask: Task<(), Error>?
    private var detectorTask: Task<(), Error>?

    static let magenta = Color(red: 0.54, green: 0.02, blue: 0.6).opacity(0.8) // #e81cff

    // The format of the audio.
    var analyzerFormat: AVAudioFormat?

    var converter = BufferConverter()
    var downloadProgress: Progress?

    var story: Binding<Story>

    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""
    
    // Callback to notify when speech has ended
    var onSpeechEnded: (() -> Void)?
    
    // Track silence duration for auto-stop
    private var lastSpeechTime: Date?
    private var silenceThreshold: TimeInterval = 3.0 // Stop after 3 seconds of silence

    static let locale = Locale(components: .init(languageCode: .english, script: nil, languageRegion: .unitedStates))

    init(story: Binding<Story>) {
        self.story = story
    }

    func setUpTranscriber() async throws {
        transcriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [.fastResults],
            attributeOptions: [.audioTimeRange]
        )

        detector = SpeechDetector()

        guard let transcriber else {
            throw TranscriptionError.failedToSetupRecognitionStream
        }

        analyzer = SpeechAnalyzer(modules: [transcriber, detector])

        do {
            try await ensureModel(transcriber: transcriber, locale: Locale.current)
        } catch let error as TranscriptionError {
            print(error)
            return
        }

        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        guard let inputSequence else { return }

        recognizerTask = Task {
            do {
                for try await case let result in transcriber.results {
                    let text = result.text
                    if result.isFinal {
                        finalizedTranscript += text
                        volatileTranscript = ""
                        updateStoryWithNewText(withFinal: text)
                    } else {
                        volatileTranscript = text
                        volatileTranscript.foregroundColor = .purple.opacity(0.4)
                    }
                }
            } catch {
                print("speech recognition failed")
            }
        }
        
        // Monitor speech detection to know when to stop
        detectorTask = Task {
            do {
                for try await case let detection in detector.results {
                    if detection.speechDetected {
                        print("Speech detected")
                        lastSpeechTime = Date()
                    } else {
                        print("Silence detected")
                        // Check if enough time has passed since last speech
                        if let lastSpeech = lastSpeechTime,
                           Date().timeIntervalSince(lastSpeech) >= silenceThreshold {
                            print("Speech has ended after \(silenceThreshold) seconds of silence")
                            onSpeechEnded?()
                        }
                    }
                }
            } catch {
                print("speech detection failed: \(error)")
            }
        }

        try await analyzer?.start(inputSequence: inputSequence)
    }

    func updateStoryWithNewText(withFinal str: AttributedString) {
        story.text.wrappedValue.append(str)
    }

    func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder, let analyzerFormat else {
            throw TranscriptionError.invalidAudioDataType
        }

        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)

        inputBuilder.yield(input)
    }

    public func finishTranscribing() async throws {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        recognizerTask?.cancel()
        recognizerTask = nil
        detectorTask?.cancel()
        detectorTask = nil
    }
}
@available(iOS 26.0, *)
extension SpokenWordTranscriber {
    public func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            throw TranscriptionError.localeNotSupported
        }

        if await installed(locale: locale) {
            return
        } else {
            try await downloadIfNeeded(for: transcriber)
        }
    }

    func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            self.downloadProgress = downloader.progress
            try await downloader.downloadAndInstall()
        }
    }

    func releaseLocales() async {
        let reserved = await AssetInventory.reservedLocales
        for locale in reserved {
            await AssetInventory.release(reservedLocale: locale)
        }
    }
}


import Foundation
import AVFoundation
import SwiftUI
@available(iOS 26.0, *)
class Recorder {
    private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation? = nil
    private let audioEngine: AVAudioEngine
    private let transcriber: SpokenWordTranscriber
    var playerNode: AVAudioPlayerNode?

    var story: Binding<Story>

    var file: AVAudioFile?
    private let url: URL

    init(transcriber: SpokenWordTranscriber, story: Binding<Story>) {
        audioEngine = AVAudioEngine()
        self.transcriber = transcriber
        self.story = story
        self.url = FileManager.default.temporaryDirectory
            .appending(component: UUID().uuidString)
            .appendingPathExtension(for: .wav)
        
        // Set up callback for when speech ends
        transcriber.onSpeechEnded = { [weak self] in
            Task { @MainActor in
                try? await self?.stopRecording()
            }
        }
    }

    func record() async throws {
        self.story.url.wrappedValue = url
        guard await isAuthorized() else {
            print("user denied mic permission")
            return
        }
#if os(iOS)
        try setUpAudioSession()
#endif
        try await transcriber.setUpTranscriber()

        for await input in try await audioStream() {
            try await self.transcriber.streamAudioToTranscriber(input)
        }
    }

    func stopRecording() async throws {
        audioEngine.stop()
        story.isDone.wrappedValue = true

        try await transcriber.finishTranscribing()

        Task {
            self.story.title.wrappedValue = try await story.wrappedValue.suggestedTitle() ?? story.title.wrappedValue
        }

    }

    func pauseRecording() {
        audioEngine.pause()
    }

    func resumeRecording() throws {
        try audioEngine.start()
    }
#if os(iOS)
    func setUpAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
#endif

    private func audioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        try setupAudioEngine()
        audioEngine.inputNode.installTap(onBus: 0,
                                         bufferSize: 4096,
                                         format: audioEngine.inputNode.outputFormat(forBus: 0)) { [weak self] (buffer, time) in
            guard let self else { return }
            writeBufferToDisk(buffer: buffer)
            self.outputContinuation?.yield(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) {
            continuation in
            outputContinuation = continuation
        }
    }

    private func setupAudioEngine() throws {
        let inputSettings = audioEngine.inputNode.inputFormat(forBus: 0).settings
        self.file = try AVAudioFile(forWriting: url,
                                    settings: inputSettings)

        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func playRecording() {
        guard let file else {
            return
        }

        playerNode = AVAudioPlayerNode()
        guard let playerNode else {
            return
        }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode,
                            to: audioEngine.outputNode,
                            format: file.processingFormat)

        playerNode.scheduleFile(file,
                                at: nil,
                                completionCallbackType: .dataPlayedBack) { _ in
        }

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            print("error")
        }
    }

    func stopPlaying() {
        audioEngine.stop()
    }
}

/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Story data model.
*/

import Foundation
import AVFoundation
import FoundationModels
@available(iOS 26.0, *)
@Observable
class Story: Identifiable {
    typealias StartTime = CMTime

    let id: UUID
    var title: String
    var text: AttributedString
    var url: URL?
    var isDone: Bool

    init(title: String, text: AttributedString, url: URL? = nil, isDone: Bool = false) {
        self.title = title
        self.text = text
        self.url = url
        self.isDone = isDone
        self.id = UUID()
    }

    func suggestedTitle() async throws -> String? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let session = LanguageModelSession(model: SystemLanguageModel.default)
        let answer = try await session.respond(to: "Here is a children's story. Can you please return your very best suggested title for it, with no other text? The title should be descriptive of the story and include the main character's name. Story: \(text.characters)")
        return answer.content.trimmingCharacters(in: .punctuationCharacters)
    }
}
@available(iOS 26.0, *)
extension Story {
    static func blank() -> Story {
        return .init(title: "New Story", text: AttributedString(""))
    }

    func storyBrokenUpByLines() -> AttributedString {
        print(String(text.characters))
        if url == nil {
            print("url was nil")
            return text
        } else {
            var final = AttributedString("")
            var working = AttributedString("")
            let copy = text
            copy.runs.forEach { run in
                if copy[run.range].characters.contains(".") {
                    working.append(copy[run.range])
                    final.append(working)
                    final.append(AttributedString("\n\n"))
                    working = AttributedString("")
                } else {
                    if working.characters.isEmpty {
                        let newText = copy[run.range].characters
                        let attributes = run.attributes
                        let trimmed = newText.trimmingPrefix(" ")
                        let newAttributed = AttributedString(trimmed, attributes: attributes)
                        working.append(newAttributed)
                    } else {
                        working.append(copy[run.range])
                    }
                }
            }

            if final.characters.isEmpty {
                return working
            }

            return final
        }
    }
}

/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Conversion code for audio inputs.
*/

import Foundation
import AVFoundation
@available(iOS 26.0, *)
class BufferConverter {
    enum Error: Swift.Error {
        case failedToCreateConverter
        case failedToCreateConversionBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else {
            return buffer
        }

        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none // Sacrifice quality of first samples in order to avoid any timestamp drift from source
        }

        guard let converter else {
            throw Error.failedToCreateConverter
        }

        let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
            throw Error.failedToCreateConversionBuffer
        }

        var nsError: NSError?
        var bufferProcessed = false

        let status = converter.convert(to: conversionBuffer, error: &nsError) { packetCount, inputStatusPointer in
            defer { bufferProcessed = true } // This closure can be called multiple times, but it only offers a single buffer.
            inputStatusPointer.pointee = bufferProcessed ? .noDataNow : .haveData
            return bufferProcessed ? nil : buffer
        }

        guard status != .error else {
            throw Error.conversionFailed(nsError)
        }

        return conversionBuffer
    }
}

/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Helper code for UI and transcription.
*/

import Foundation
import AVFoundation
import SwiftUI
@available(iOS 26.0, *)
extension Story: Equatable {
    static func == (lhs: Story, rhs: Story) -> Bool {
        lhs.id == rhs.id
    }
}

@available(iOS 26.0, *)
extension Story: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum TranscriptionState {
    case transcribing
    case notTranscribing
}

public enum TranscriptionError: Error {
    case couldNotDownloadModel
    case failedToSetupRecognitionStream
    case invalidAudioDataType
    case localeNotSupported
    case noInternetForModelDownload
    case audioFilePathNotFound

    var descriptionString: String {
        switch self {

        case .couldNotDownloadModel:
            return "Could not download the model."
        case .failedToSetupRecognitionStream:
            return "Could not set up the speech recognition stream."
        case .invalidAudioDataType:
            return "Unsupported audio format."
        case .localeNotSupported:
            return "This locale is not yet supported by SpeechAnalyzer."
        case .noInternetForModelDownload:
            return "The model could not be downloaded because the user is not connected to internet."
        case .audioFilePathNotFound:
            return "Couldn't write audio to file."
        }
    }
}

public enum RecordingState: Equatable {
    case stopped
    case recording
    case paused
}

public enum PlaybackState: Equatable {
    case playing
    case notPlaying
}

public struct AudioData: @unchecked Sendable {
    var buffer: AVAudioPCMBuffer
    var time: AVAudioTime
}

@available(iOS 26.0, *)
// Ask for permission to access the microphone.
extension Recorder {
    func isAuthorized() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }

        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    func writeBufferToDisk(buffer: AVAudioPCMBuffer) {
        do {
            try self.file?.write(from: buffer)
        } catch {
            print("file writing error: \(error)")
        }
    }
}

extension AVAudioPlayerNode {
    var currentTime: TimeInterval {
        guard let nodeTime: AVAudioTime = self.lastRenderTime, let playerTime: AVAudioTime = self.playerTime(forNodeTime: nodeTime) else { return 0 }

        return Double(playerTime.sampleTime) / playerTime.sampleRate
    }
}
@available(iOS 26.0, *)
extension TranscriptView {

    func handlePlayback() {
        guard story.url != nil else {
            return
        }

        if isPlaying {
            recorder.playRecording()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                currentPlaybackTime = recorder.playerNode?.currentTime ?? 0.0
            }
        } else {
            recorder.stopPlaying()
            currentPlaybackTime = 0.0
            timer = nil
        }
    }

    func handleRecordingButtonTap() {
        isRecording.toggle()
    }

    func handlePlayButtonTap() {
        isPlaying.toggle()
    }

    @ViewBuilder func textScrollView(attributedString: AttributedString) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                textWithHighlighting(attributedString: attributedString)
                Spacer()
            }
        }
    }

    func attributedStringWithCurrentValueHighlighted(attributedString: AttributedString) -> AttributedString {
        var copy = attributedString
        copy.runs.forEach { run in
            if shouldBeHighlighted(attributedStringRun: run) {
                let range = run.range
                copy[range].backgroundColor = .mint.opacity(0.2)
            }
        }
        return copy
    }

    func shouldBeHighlighted(attributedStringRun: AttributedString.Runs.Run) -> Bool {
        guard isPlaying else { return false }
        let start = attributedStringRun.audioTimeRange?.start.seconds
        let end = attributedStringRun.audioTimeRange?.end.seconds
        guard let start, let end else {
            return false
        }

        if end < currentPlaybackTime { return false }

        if start < currentPlaybackTime, currentPlaybackTime < end {
            return true
        }

        return false
    }

    @ViewBuilder func textWithHighlighting(attributedString: AttributedString) -> some View {
        Group {
            Text(attributedStringWithCurrentValueHighlighted(attributedString: attributedString))
                .font(.title)
        }
    }
}

import Foundation
import SwiftUI
import Speech
import AVFoundation
@available(iOS 26.0, *)
struct TranscriptView: View {
    @Binding var story: Story
    @State var isRecording = false
    @State var isPlaying = false

    @State var recorder: Recorder
    @State var speechTranscriber: SpokenWordTranscriber

    @State var downloadProgress = 0.0

    @State var currentPlaybackTime = 0.0

    @State var timer: Timer?

    init(story: Binding<Story>) {
        self._story = story
        let transcriber = SpokenWordTranscriber(story: story)
        recorder = Recorder(transcriber: transcriber, story: story)
        speechTranscriber = transcriber
    }

    var body: some View {
        VStack(alignment: .leading) {
            Group {
                if !story.isDone {
                    liveRecordingView
                } else {
                    playbackView
                }
            }
            Spacer()
        }
        .padding(20)
        .navigationTitle(story.title)
        .toolbar {
            ToolbarItem {
                Button {
                    handleRecordingButtonTap()
                } label: {
                    if isRecording {
                        Label("Stop", systemImage: "pause.fill").tint(.red)
                    } else {
                        Label("Record", systemImage: "record.circle").tint(.red)
                    }
                }
                .disabled(story.isDone)
            }

            ToolbarItem {
                Button {
                    handlePlayButtonTap()
                } label: {
                    Label("Play", systemImage: isPlaying ? "pause.fill" : "play").foregroundStyle(.blue).font(.title)
                }
                .disabled(!story.isDone)
            }

            ToolbarItem {
                ProgressView(value: downloadProgress, total: 100)
            }

        }
        .onChange(of: isRecording) { oldValue, newValue in
            guard newValue != oldValue else { return }
            if newValue == true {
                Task {
                    do {
                        try await recorder.record()
                    } catch {
                        print("could not record: \(error)")
                    }
                }
            } else {
                Task {
                    try await recorder.stopRecording()
                }
            }
        }
        .onChange(of: isPlaying) {
            handlePlayback()
        }
    }

    @ViewBuilder
    var liveRecordingView: some View {
        Text(speechTranscriber.finalizedTranscript + speechTranscriber.volatileTranscript)
            .font(.title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var playbackView: some View {
        textScrollView(attributedString: story.storyBrokenUpByLines())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
