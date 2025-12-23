/*

 ## Overview

 `HAAssistTranscriberManager` is a simplified wrapper around `HAAssistTranscriber` that provides
 a clean, observable API for SwiftUI views. It handles all setup, audio engine management,
 and automatic silence detection internally.

 ## Basic Usage

 ### 1. Initialize in your SwiftUI view or view model

 ```swift
 @State private var transcriber = HAAssistTranscriberManager()
 ```

 ### 2. Start transcription

 ```swift
 Task {
     try await transcriber.start()
 }
 ```

 ### 3. Observe state and transcription

 ```swift
 // Check current state
 if transcriber.state == .transcribing {
     // Currently recording
 }

 // Access transcription text
 Text(transcriber.lastTranscription)
 ```

 ### 4. Stop manually (optional)

 ```swift
 Task {
     try await transcriber.stop()
 }
 ```

 ## Observable Properties

 - **`state: HAAssistTranscriptionState`** - Current state (.transcribing or .notTranscribing)
 - **`lastTranscription: String`** - Latest transcription result (auto-updates)
 - **`downloadProgress: Progress?`** - Progress for model download (if needed)

 ## Configuration Properties

 - **`silenceThreshold: Measurement<UnitDuration>`** - Duration of silence before auto-stop (default: 2 seconds)
 - **`autoStopEnabled: Bool`** - Whether to auto-stop on silence detection (default: true)

 ## Methods

 - **`start() async throws`** - Start transcription with microphone
 - **`stop() async throws`** - Stop transcription manually
 - **`reset()`** - Clear transcription text

 ## Automatic Features

 ✅ **Microphone permission handling** - Requests permission automatically
 ✅ **Audio engine setup** - Configures AVAudioEngine internally
 ✅ **Silence detection** - Auto-stops after configured silence duration
 ✅ **Model download** - Downloads speech model if needed
 ✅ **Real-time updates** - Observable properties update automatically
 ✅ **Thread safety** - All operations are @MainActor safe

 ## Example View Model

 ```swift
 @available(iOS 26.0, *)
 @Observable
 final class MyViewModel {
     private(set) var transcriber = HAAssistTranscriberManager()

     func startListening() async {
         do {
             // Configure if needed
             transcriber.silenceThreshold = .init(value: 3.0, unit: .seconds)
             transcriber.autoStopEnabled = true

             try await transcriber.start()
         } catch {
             print("Failed to start: \(error)")
         }
     }

     func stopListening() async {
         try? await transcriber.stop()
     }
 }
 ```

 ## Example SwiftUI View

 ```swift
 @available(iOS 26.0, *)
 struct TranscriptionView: View {
     @State private var transcriber = HAAssistTranscriberManager()

     var body: some View {
         VStack {
             // Show status
             Text(transcriber.state == .transcribing ? "🎤 Listening..." : "Ready")

             // Show transcription
             Text(transcriber.lastTranscription)
                 .padding()

             // Controls
             Button("Start") {
                 Task { try? await transcriber.start() }
             }
             .disabled(transcriber.state == .transcribing)

             Button("Stop") {
                 Task { try? await transcriber.stop() }
             }
             .disabled(transcriber.state == .notTranscribing)
         }
     }
 }
 ```

 ## Notes

 - Requires iOS 26.0+
 - Automatically handles speech model downloads
 - Uses the device's current locale
 - Cleans up resources automatically on deinit
 - Thread-safe with @MainActor annotation

 */
