import Intents
import ObjectMapper
import PromiseKit

class AssistInAppIntentHandler: NSObject, AssistInAppIntentHandling {
    typealias Intent = AssistInAppIntent

    // MARK: - Server

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

    // MARK: - Pipeline

    func resolvePipeline(
        for intent: AssistInAppIntent,
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
        for intent: AssistInAppIntent,
        with completion: @escaping (INObjectCollection<IntentAssistPipeline>?, (any Error)?) -> Void
    ) {
        guard let server = Current.servers.server(for: intent) else {
            completion(nil, nil)
            return
        }

        AssistService(server: server).fetchPipelines { response in
            guard let pipelines = response?.pipelines else {
                completion(nil, nil)
                return
            }
            let result: [IntentAssistPipeline] = pipelines.map { pipeline in
                IntentAssistPipeline(identifier: pipeline.id, display: pipeline.name)
            }
            completion(.init(items: result), nil)
        }
    }

    // MARK: With Voice

    func resolveWithVoice(for intent: AssistInAppIntent) async -> INBooleanResolutionResult {
        INBooleanResolutionResult.success(with: intent.withVoice == 1 ? true : false)
    }
}
