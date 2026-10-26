import AppIntents
import Shared

// AppIntent that open app needs to have it's target the widget extension AND app target!
struct OpenHomeAssistantAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.open_home_assistant.title",
        defaultValue: "Open Home Assistant"
    )

    static var description = IntentDescription(.init(
        "app_intents.open_home_assistant.description",
        defaultValue: "Opens the Home Assistant app"
    ))

    static var openAppWhenRun: Bool = true
    // `openAppWhenRun` is deprecated from iOS 26; both stay until the deployment target passes 26.
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
