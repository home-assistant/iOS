import AppIntents
import Shared

struct RenderTemplateAppIntent: AppIntent, CustomIntentMigratedAppIntent {
    // Carries over shortcuts built with the deprecated SiriKit RenderTemplateIntent
    static let intentClassName = "RenderTemplateIntent"

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
        await Current.connectivity.refreshNetworkInformation()
        guard let server = server.getServer() else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let rendered = try await AppIntentServerAPI.renderTemplate(server: server, template: template)
        return .result(value: rendered)
    }
}
