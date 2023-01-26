import Intents
import ObjectMapper
import PromiseKit

@available(iOS 13, watchOS 6, *)
class AssistIntentHandler: NSObject, AssistIntentHandling {
    typealias Intent = AssistIntent

    func resolveServer(for intent: Intent, with completion: @escaping (IntentServerResolutionResult) -> Void) {
        if let server = Current.servers.server(for: intent) {
            completion(.success(with: .init(server: server)))
        } else {
            completion(.needsValue())
        }
    }

    func provideServerOptions(for intent: Intent, with completion: @escaping ([IntentServer]?, Error?) -> Void) {
        completion(IntentServer.all, nil)
    }

    @available(iOS 14, watchOS 7, *)
    func provideServerOptionsCollection(
        for intent: Intent,
        with completion: @escaping (INObjectCollection<IntentServer>?, Error?) -> Void
    ) {
        completion(.init(items: IntentServer.all), nil)
    }

    func defaultLanguage(for intent: AssistIntent) -> IntentLanguage? {
        Locale.current.asIntentLanguage
    }

    func provideLanguageOptions(
        for intent: AssistIntent,
        with completion: @escaping ([IntentLanguage]?, Error?) -> Void
    ) {
        completion(Locale.current.intentLanguages, nil)
    }

    @available(iOS 14, watchOS 7, *)
    func provideLanguageOptionsCollection(
        for intent: AssistIntent,
        with completion: @escaping (INObjectCollection<IntentLanguage>?, Error?) -> Void
    ) {
        completion(.init(items: Locale.current.intentLanguages), nil)
    }

    func handle(intent: AssistIntent, completion: @escaping (AssistIntentResponse) -> Void) {
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
}
