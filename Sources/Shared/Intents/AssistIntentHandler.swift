import Intents
import ObjectMapper
import PromiseKit

#if os(iOS)
import Speech
#endif

@available(iOS 13, watchOS 6, *)
public class AssistIntentHandler: NSObject, AssistIntentHandling {
    public typealias Intent = AssistIntent

    #if os(iOS)
    // TODO: Make it dynamic to home assistant pipeline
    private let audioRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    #endif

    public func resolveServer(for intent: Intent, with completion: @escaping (IntentServerResolutionResult) -> Void) {
        if let server = Current.servers.server(for: intent) {
            completion(.success(with: .init(server: server)))
        } else {
            completion(.needsValue())
        }
    }

    public func provideServerOptions(for intent: Intent, with completion: @escaping ([IntentServer]?, Error?) -> Void) {
        completion(IntentServer.all, nil)
    }

    @available(iOS 14, watchOS 7, *)
    public func provideServerOptionsCollection(
        for intent: Intent,
        with completion: @escaping (INObjectCollection<IntentServer>?, Error?) -> Void
    ) {
        completion(.init(items: IntentServer.all), nil)
    }

    public func defaultLanguage(for intent: AssistIntent) -> IntentLanguage? {
        Locale.current.asIntentLanguage
    }

    public func provideLanguageOptions(
        for intent: AssistIntent,
        with completion: @escaping ([IntentLanguage]?, Error?) -> Void
    ) {
        completion(Locale.current.intentLanguages, nil)
    }

    @available(iOS 14, watchOS 7, *)
    public func provideLanguageOptionsCollection(
        for intent: AssistIntent,
        with completion: @escaping (INObjectCollection<IntentLanguage>?, Error?) -> Void
    ) {
        completion(.init(items: Locale.current.intentLanguages), nil)
    }

    public func handle(intent: AssistIntent, completion: @escaping (AssistIntentResponse) -> Void) {
        guard let server = Current.servers.server(for: intent) else {
            completion(.failure(error: "no server provided"))
            return
        }

        guard server.info.version >= .conversationWebhook else {
            completion(.failure(error: HomeAssistantAPI.APIError.mustUpgradeHomeAssistant(
                current: server.info.version,
                minimum: .conversationWebhook
            ).localizedDescription))
            return
        }

        struct ConversationResponse: ImmutableMappable {
            var speech: String

            init(map: Map) throws {
                self.speech = try map.value("response.speech.plain.speech")
            }
        }

        Current.webhooks.sendEphemeral(
            server: server,
            request: .init(
                type: "conversation_process",
                data: [
                    "text": intent.text,
                    "language": intent.language?.identifier ?? Locale.current.identifier,
                ]
            )
        ).map { (original: [String: Any]) -> (ConversationResponse, [String: Any]) in
            let object: ConversationResponse = try Mapper().map(JSONObject: original)
            return (object, original)
        }.done { object, original in
            Current.Log.info("finishing with \(object)")
            let value = IntentAssistResult(identifier: nil, display: object.speech)
            value.json = String(decoding: try JSONSerialization.data(withJSONObject: original), as: UTF8.self)
            completion(.success(result: value))
        }.catch { error in
            Current.Log.error("erroring with \(error)")
            completion(.failure(error: error.localizedDescription))
        }
    }

    #if os(iOS)
    public func handle(
        audioData: Data,
        completion: @escaping (_ inputText: String, _ response: AssistIntentResponse) -> Void
    ) {
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
        audioRecognizer?.recognitionTask(with: audioRequest, resultHandler: { [weak self] result, error in
            if let error = error {
                Current.Log.error("Transcription error: \(error.localizedDescription)")
                completion("", .failure(error: NSLocalizedString("Could not recognize audio", comment: "")))
            } else if let result = result {
                guard result.isFinal else { return }
                let transcription = result.bestTranscription.formattedString
                Current.Log.info("Transcription: \(transcription)")
                let intent = AssistIntent()
                intent.text = transcription
                self?.handle(intent: intent, completion: { response in
                    completion(transcription, response)
                })
            }
        })
    }
    #endif
}
