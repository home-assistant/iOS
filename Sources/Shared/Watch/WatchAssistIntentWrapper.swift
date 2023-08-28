import Foundation
#if os(iOS)
import Speech
#endif

public protocol WatchAssistIntentWrapping {
    func handle(audioData: Data, completion: @escaping (_ inputText: String, _ response: AssistIntentResponse) -> Void)
}

public class WatchAssistIntentWrapper: WatchAssistIntentWrapping {
    #if os(iOS)
    // TODO: Make it dynamic to home assistant pipeline
    private let audioRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    #endif

    public func handle(
        audioData: Data,
        completion: @escaping (_ inputText: String, _ response: AssistIntentResponse) -> Void
    ) {
        #if os(iOS)
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion("", .failure(error: NSLocalizedString("Could not get documents directory", comment: "")))
            return
        }
        let audioFileURL = documentsDirectory.appendingPathComponent("watch-assist-input.m4a")

        do {
            try audioData.write(to: audioFileURL)
            Current.Log.info("Audio saved at: \(audioFileURL)")
        } catch {
            Current.Log.error("Failed to analyze audio in iOS")
            completion("", .failure(error: NSLocalizedString("Failed to analyze audio in iOS", comment: "")))
        }

        let audioRequest = SFSpeechURLRecognitionRequest(url: audioFileURL)
        audioRecognizer?.recognitionTask(with: audioRequest, resultHandler: { result, error in
            if let error = error {
                Current.Log.error("Transcription error: \(error.localizedDescription)")
                completion("", .failure(error: NSLocalizedString("Could not recognize audio", comment: "")))
            } else if let result = result {
                guard result.isFinal else { return }
                let transcription = result.bestTranscription.formattedString
                Current.Log.info("Transcription: \(transcription)")
                let intent = AssistIntent()
                intent.text = transcription
                Current.assistIntentHandler?.handle(intent: intent, completion: { response in
                    completion(transcription, response)
                })
            }
        })
        #endif
    }
}
