import AppIntents
import HAKit
import Shared

struct RenderTemplateAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.render_template.title",
        defaultValue: "Render template"
    )

    static var description = IntentDescription(.init(
        "app_intents.render_template.description",
        defaultValue: "Render a Home Assistant template. Only users with the admin role can perform this action."
    ))

    @Parameter(title: .init("app_intents.server.title", defaultValue: "Server"))
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("app_intents.render_template.template.title", defaultValue: "Template"),
        default: "{{ now() }}"
    )
    var template: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await Current.connectivity.syncNetworkInformation()
        guard let server = server.getServer(),
              let connection = Current.api(for: server)?.connection else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let rendered = try await connection.renderTemplate(template)
        return .result(value: rendered)
    }
}

private extension HAConnection {
    func renderTemplate(_ template: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            subscribe(to: .renderTemplate(template), initiated: { result in
                if case let .failure(error) = result {
                    continuation.resume(throwing: error)
                }
            }, handler: { token, data in
                token.cancel()
                continuation.resume(returning: String(describing: data.result))
            })
        }
    }
}
