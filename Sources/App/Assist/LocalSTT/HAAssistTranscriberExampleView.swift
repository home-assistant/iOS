//
//  HAAssistTranscriberExampleView.swift
//
//  Example usage of HAAssistTranscriberManager in SwiftUI
//

import SwiftUI

@available(iOS 26.0, *)
struct HAAssistTranscriberExampleView: View {
    @State private var transcriber = HAAssistTranscriberManager()
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Circle()
                    .fill(transcriber.state == .transcribing ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(transcriber.state == .transcribing ? "Recording..." : "Stopped")
                    .font(.headline)
            }
            
            // Transcription text
            ScrollView {
                Text(transcriber.lastTranscription.isEmpty ? "Transcription will appear here..." : transcriber.lastTranscription)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 300)
            
            // Download progress (if downloading model)
            if let progress = transcriber.downloadProgress, !progress.isFinished {
                ProgressView("Downloading speech model...", value: progress.fractionCompleted, total: 1.0)
            }
            
            // Controls
            HStack(spacing: 20) {
                Button {
                    Task {
                        do {
                            try await transcriber.start()
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Start", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(transcriber.state == .transcribing)
                
                Button {
                    Task {
                        do {
                            try await transcriber.stop()
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(transcriber.state == .notTranscribing)
                
                Button {
                    transcriber.reset()
                } label: {
                    Label("Reset", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            // Configuration
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Configuration")
                        .font(.headline)
                    
                    Toggle("Auto-stop on silence", isOn: $transcriber.autoStopEnabled)
                    
                    HStack {
                        Text("Silence threshold: \(Int(transcriber.silenceThreshold.value))s")
                        Slider(value: Binding(
                            get: { transcriber.silenceThreshold.value },
                            set: { transcriber.silenceThreshold = .init(value: $0, unit: .seconds) }
                        ), in: 1...5, step: 0.5)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .navigationTitle("Voice Transcription")
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        NavigationStack {
            HAAssistTranscriberExampleView()
        }
    } else {
        Text("Requires iOS 26.0+")
    }
}
