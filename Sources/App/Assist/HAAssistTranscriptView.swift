//
//  HAAssistTranscriptView.swift
//
//  Main UI for recording and playing back transcriptions
//

import Foundation
import SwiftUI
import Speech
import AVFoundation

@available(iOS 26.0, *)
struct HAAssistTranscriptView: View {
    @Binding var story: HAAssistStory
    @State var isRecording = false
    @State var isPlaying = false

    @State var recorder: HAAssistRecorder
    @State var speechTranscriber: HAAssistTranscriber

    @State var downloadProgress = 0.0

    @State var currentPlaybackTime = 0.0

    @State var timer: Timer?

    init(story: Binding<HAAssistStory>) {
        self._story = story
        let transcriber = HAAssistTranscriber(story: story)
        recorder = HAAssistRecorder(transcriber: transcriber, story: story)
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

// MARK: - Helper Methods
@available(iOS 26.0, *)
extension HAAssistTranscriptView {
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
