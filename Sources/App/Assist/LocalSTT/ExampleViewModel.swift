//
//  ExampleViewModel.swift
//
//  Example view model showing recommended usage pattern
//

import Foundation
import Observation

@available(iOS 26.0, *)
@Observable
@MainActor
final class ExampleViewModel {
    
    // MARK: - Public Properties
    
    /// The transcriber instance - observe state and lastTranscription from here
    private(set) var transcriber = HAAssistTranscriberManager()
    
    /// Error message to display in UI
    private(set) var errorMessage: String?
    
    /// Whether we're currently processing
    private(set) var isProcessing = false
    
    // MARK: - Initialization
    
    init() {
        // Configure transcriber defaults
        transcriber.silenceThreshold = .init(value: 2.5, unit: .seconds)
        transcriber.autoStopEnabled = true
    }
    
    // MARK: - Actions
    
    func startTranscribing() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            try await transcriber.start()
            print("✅ Transcription started successfully")
        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }
        
        isProcessing = false
    }
    
    func stopTranscribing() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            try await transcriber.stop()
            print("✅ Transcription stopped successfully")
        } catch {
            errorMessage = "Failed to stop: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }
        
        isProcessing = false
    }
    
    func clearTranscription() {
        transcriber.reset()
        errorMessage = nil
    }
    
    func updateSilenceThreshold(seconds: Double) {
        transcriber.silenceThreshold = .init(value: seconds, unit: .seconds)
    }
    
    func toggleAutoStop() {
        transcriber.autoStopEnabled.toggle()
    }
    
    // MARK: - Computed Properties
    
    var isRecording: Bool {
        transcriber.state == .transcribing
    }
    
    var hasTranscription: Bool {
        !transcriber.lastTranscription.isEmpty
    }
    
    var transcriptionText: String {
        transcriber.lastTranscription
    }
}

// MARK: - Usage in SwiftUI View

/*
@available(iOS 26.0, *)
struct ContentView: View {
    @State private var viewModel = ExampleViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Status
            Text(viewModel.isRecording ? "🎤 Recording" : "Ready")
                .font(.headline)
            
            // Transcription
            if viewModel.hasTranscription {
                ScrollView {
                    Text(viewModel.transcriptionText)
                        .padding()
                }
                .frame(maxHeight: 300)
            }
            
            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            // Controls
            HStack {
                Button("Start") {
                    Task { await viewModel.startTranscribing() }
                }
                .disabled(viewModel.isRecording || viewModel.isProcessing)
                
                Button("Stop") {
                    Task { await viewModel.stopTranscribing() }
                }
                .disabled(!viewModel.isRecording || viewModel.isProcessing)
                
                Button("Clear") {
                    viewModel.clearTranscription()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
*/
