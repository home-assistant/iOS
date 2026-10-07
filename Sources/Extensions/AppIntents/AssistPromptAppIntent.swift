import AppIntents
import Foundation
import Shared

@available(watchOS 9.4, *)
struct AssistPromptAppIntent: AppIntent, CustomIntentMigratedAppIntent {
    // Carries over shortcuts built with the deprecated SiriKit AssistIntent
    static let intentClassName = "AssistIntent"

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

    /// Optional so a Siri phrase runs without a follow-up; nil uses the first server's preferred pipeline.
    @Parameter(
        title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"),
        description: .init(
            "app_intents.assist_prompt.pipeline.description",
            defaultValue: "Leave empty to use the preferred pipeline of your first server"
        )
    )
    var pipeline: AssistPipelineEntity?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.refreshNetworkInformation()
        // A saved pipeline outlives its server, and its id means nothing to a different one.
        let server: Server
        if let pipeline {
            guard let pipelineServer = Current.servers.server(for: .init(rawValue: pipeline.serverId)) else {
                throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
            }
            server = pipelineServer
        } else {
            guard let firstServer = Current.servers.all.first else {
                throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
            }
            server = firstServer
        }

        guard server.info.version >= .conversationWebhook else {
            throw ShortcutAppIntentError(HomeAssistantAPI.APIError.mustUpgradeHomeAssistant(
                current: server.info.version,
                minimum: .conversationWebhook
            ).localizedDescription)
        }

        let result = try await AppIntentServerAPI.assist(
            server: server,
            prompt: prompt,
            pipelineId: pipeline?.pipelineId
        )
        return .result(value: result)
    }
}
