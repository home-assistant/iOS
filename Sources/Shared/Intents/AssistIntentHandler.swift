import Intents
import ObjectMapper
import PromiseKit

class AssistIntentHandler: NSObject, AssistIntentHandling {
    typealias Intent = AssistIntent

    private var intentCompletion: ((AssistIntentResponse) -> Void)?
    private var assistService: AssistService?

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

        guard server.info.version >= .conversationWebhook else {
            completion(.failure(error: HomeAssistantAPI.APIError.mustUpgradeHomeAssistant(
                current: server.info.version,
                minimum: .conversationWebhook
            ).localizedDescription))
            return
        }

        intentCompletion = completion
        assistService = AssistService(server: server)
        assistService?.delegate = self
        assistService?.assist(source: .text(input: intent.text ?? "", pipelineId: intent.pipeline?.identifier ?? nil))
    }

    func resolvePipeline(
        for intent: AssistIntent,
        with completion: @escaping (IntentAssistPipelineResolutionResult) -> Void
    ) {
        guard let server = Current.servers.server(for: intent) else {
            completion(.needsValue())
            return
        }

        AssistService(server: server).fetchPipelines { response in
            guard let pipelines = response?.pipelines else {
                completion(.needsValue())
                return
            }
            guard let result = pipelines.first(where: { pipeline in
                pipeline.id == intent.pipeline?.identifier
            }) else {
                completion(.needsValue())
                return
            }
            completion(.success(with: .init(identifier: result.id, display: result.name)))
        }
    }

    func providePipelineOptionsCollection(
        for intent: AssistIntent,
        with completion: @escaping (INObjectCollection<IntentAssistPipeline>?, (any Error)?) -> Void
    ) {
        guard let server = Current.servers.server(for: intent) else {
            completion(.init(items: []), nil)
            return
        }

        AssistService(server: server).fetchPipelines { response in
            guard let pipelines = response?.pipelines else {
                completion(.init(items: []), nil)
                return
            }
            completion(.init(items: pipelines.map({ pipeline in
                IntentAssistPipeline(identifier: pipeline.id, display: pipeline.name)
            })), nil)
        }
    }
}

extension AssistIntentHandler: AssistServiceDelegate {
    func didReceiveEvent(_ event: AssistEvent) {
        /* no-op */
    }

    func didReceiveSttContent(_ content: String) {
        /* no-op */
    }

    func didReceiveIntentEndContent(_ content: String) {
        intentCompletion?(.success(result: .init(identifier: nil, display: content)))
    }

    func didReceiveGreenLightForAudioInput() {
        /* no-op */
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        /* no-op */
    }

    func didReceiveError(code: String, message: String) {
        intentCompletion?(.failure(error: "\(code) - \(message)"))
    }
}
