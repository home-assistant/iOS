import AVFoundation
import Foundation
import SwiftUI

@available(iOS 26.0, *)
class HAAssistRecorder {
    private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private let audioEngine: AVAudioEngine
    private let transcriber: HAAssistTranscriber
    var playerNode: AVAudioPlayerNode?

    var file: AVAudioFile?
    private let url: URL

    var hasRecording: Bool {
        file != nil
    }

    // Callback to notify when recording has ended
    var onRecordingEnded: (() -> Void)?

    init(transcriber: HAAssistTranscriber) {
        self.audioEngine = AVAudioEngine()
        self.transcriber = transcriber
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
        guard await isAuthorized() else {
            print("user denied mic permission")
            return
        }
        #if os(iOS)
        try setUpAudioSession()
        #endif
        try await transcriber.setUpTranscriber()

        for await input in try await audioStream() {
            try await transcriber.streamAudioToTranscriber(input)
        }
    }

    func stopRecording() async throws {
        audioEngine.stop()

        try await transcriber.finishTranscribing()

        onRecordingEnded?()
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
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: audioEngine.inputNode
                .outputFormat(forBus: 0)
        ) { [weak self] buffer, _ in
            guard let self else { return }
            writeBufferToDisk(buffer: buffer)
            outputContinuation?.yield(buffer)
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
        file = try AVAudioFile(
            forWriting: url,
            settings: inputSettings
        )

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
        audioEngine.connect(
            playerNode,
            to: audioEngine.outputNode,
            format: file.processingFormat
        )

        playerNode.scheduleFile(
            file,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { _ in
        }

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            print("error: \(error)")
        }
    }

    func stopPlaying() {
        audioEngine.stop()
    }
}

// MARK: - Authorization & File Writing

@available(iOS 26.0, *)
extension HAAssistRecorder {
    func isAuthorized() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }

        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    func writeBufferToDisk(buffer: AVAudioPCMBuffer) {
        do {
            try file?.write(from: buffer)
        } catch {
            print("file writing error: \(error)")
        }
    }
}
