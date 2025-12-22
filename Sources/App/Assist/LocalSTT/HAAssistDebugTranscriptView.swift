//
//  HAAssistTranscriptView.swift
//
//  Main UI for recording and transcribing voice to text
//

import Foundation
import SwiftUI
import Speech
import AVFoundation

@available(iOS 26.0, *)
struct HAAssistDebugTranscriptView: View {
    @State var isRecording = false
    @State var isPlaying = false

    @State var recorder: HAAssistRecorder
    @State var speechTranscriber: HAAssistTranscriber
    
    @State var isDone = false
    @State var downloadProgress = 0.0
    @State var currentPlaybackTime = 0.0
    @State var timer: Timer?

    init() {
        let transcriber = HAAssistTranscriber()
        recorder = HAAssistRecorder(transcriber: transcriber)
        speechTranscriber = transcriber
    }

    var body: some View {
        VStack(alignment: .leading) {
            Group {
                if !isDone {
                    liveRecordingView
                } else {
                    playbackView
                }
            }
            Spacer()
        }
        .padding(20)
        .navigationTitle("Voice Transcription")
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
                .disabled(isDone)
            }

            ToolbarItem {
                if downloadProgress > 0 && downloadProgress < 100 {
                    ProgressView(value: downloadProgress, total: 100)
                }
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
                    isDone = true
                }
            }
        }
        .onAppear {
            // Set up callback for recording completion
            recorder.onRecordingEnded = {
                Task { @MainActor in
                    isDone = true
                }
            }
        }
    }

    @ViewBuilder
    var liveRecordingView: some View {
        ScrollView {
            Text(speechTranscriber.finalizedTranscript + speechTranscriber.volatileTranscript)
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    var playbackView: some View {
        textScrollView(attributedString: speechTranscriber.finalizedTranscript)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helper Methods
@available(iOS 26.0, *)
extension HAAssistDebugTranscriptView {

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
