//
//  HAAssistTranscriber.swift
//
//  Speech transcription handler for spoken word recording
//

import Speech
import AVFoundation
import Foundation
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class HAAssistTranscriber {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var transcriber: SpeechTranscriber?
    private var detector: SpeechDetector!
    private var analyzer: SpeechAnalyzer?
    private var recognizerTask: Task<(), Error>?
    private var detectorTask: Task<(), Error>?

    // The format of the audio.
    var analyzerFormat: AVAudioFormat?

    var converter = HAAssistBufferConverter()
    var downloadProgress: Progress?

    var story: Binding<HAAssistStory>

    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""
    
    // Callback to notify when speech has ended
    var onSpeechEnded: (() -> Void)?
    
    // Track silence duration for auto-stop
    private var lastSpeechTime: Date?
    var silenceThreshold: TimeInterval = 3.0 // Stop after 3 seconds of silence
    var autoStopEnabled: Bool = true

    init(story: Binding<HAAssistStory>) {
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
            throw HAAssistTranscriptionError.failedToSetupRecognitionStream
        }

        analyzer = SpeechAnalyzer(modules: [transcriber, detector])

        do {
            try await ensureModel(transcriber: transcriber, locale: Locale.current)
        } catch let error as HAAssistTranscriptionError {
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
                print("speech recognition failed: \(error)")
            }
        }
        
        // Monitor speech detection to know when to stop
        detectorTask = Task {
            do {
                for try await case let detection in detector.results {
                    if detection.speechDetected {
                        print("Speech detected")
                        lastSpeechTime = Date()
                    } else if autoStopEnabled {
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
            throw HAAssistTranscriptionError.invalidAudioDataType
        }

        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)

        inputBuilder.yield(input)
    }

    func finishTranscribing() async throws {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        recognizerTask?.cancel()
        recognizerTask = nil
        detectorTask?.cancel()
        detectorTask = nil
    }
}

// MARK: - Model Management
@available(iOS 26.0, *)
extension HAAssistTranscriber {
    func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            throw HAAssistTranscriptionError.localeNotSupported
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
