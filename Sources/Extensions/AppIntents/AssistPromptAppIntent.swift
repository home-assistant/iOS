import AppIntents
import Foundation
import Shared

struct AssistPromptAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.assist_prompt.title",
        defaultValue: "Assist prompt"
    )

    static var description = IntentDescription(.init(
        "app_intents.assist_prompt.description",
        defaultValue: "Send a text prompt to Assist"
    ))

    @Parameter(title: .init("app_intents.assist_prompt.prompt.title", defaultValue: "Prompt"))
    var prompt: String

    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: pipeline.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        guard server.info.version >= .conversationWebhook else {
            throw ShortcutAppIntentError(HomeAssistantAPI.APIError.mustUpgradeHomeAssistant(
                current: server.info.version,
                minimum: .conversationWebhook
            ).localizedDescription)
        }

        let result = try await AssistPromptRunner(server: server).assist(
            prompt: prompt,
            pipelineId: pipeline.pipelineId
        )
        return .result(value: result)
    }
}

private final class AssistPromptRunner: NSObject, AssistServiceDelegate {
    private let server: Server
    private var assistService: AssistService?
    private var continuation: CheckedContinuation<String, Error>?

    init(server: Server) {
        self.server = server
        super.init()
    }

    func assist(prompt: String, pipelineId: String?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let assistService = AssistService(server: server)
            assistService.delegate = self
            self.assistService = assistService
            assistService.assist(source: .text(input: prompt, pipelineId: pipelineId, expectTTS: false))
        }
    }

    func didReceiveStreamResponseChunk(_ content: String) {
        /* no-op */
    }

    func didReceiveEvent(_ event: AssistEvent) {
        /* no-op */
    }

    func didReceiveSttContent(_ content: String) {
        /* no-op */
    }

    func didReceiveIntentEndContent(_ content: String) {
        resume(with: .success(content))
    }

    func didReceiveGreenLightForAudioInput() {
        /* no-op */
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        /* no-op */
    }

    func didReceiveError(code: String, message: String) {
        resume(with: .failure(ShortcutAppIntentError("\(code) - \(message)")))
    }

    private func resume(with result: Swift.Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        assistService = nil

        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}
