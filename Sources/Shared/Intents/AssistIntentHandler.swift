import Intents
import PromiseKit
import ObjectMapper

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

    func handle(intent: AssistIntent, completion: @escaping (AssistIntentResponse) -> Void) {
        guard let server = Current.servers.server(for: intent) else {
            completion(.failure(error: "no server provided"))
            return
        }

        struct ConversationResponse: ImmutableMappable {
            var speech: String

            init(map: Map) throws {
                self.speech = try map.value("response.speech.plain.speech")
            }
        }

        let promise: Promise<ConversationResponse> = Current.webhooks.sendEphemeral(
            server: server,
            request: .init(
                type: "assist",
                data: [
                    "text": intent.text,
                    "language": Current.localized.currentLanguage,
                ]
            )
        )

        promise.done { result in
            let value = AssistIntentResponse()
            value.result = result.speech
            completion(value)
        }.catch { error in
            completion(.failure(error: error.localizedDescription))
        }
    }
}
