import AppIntents

struct WatchAssistAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.watch_assist.title",
        defaultValue: "Assist"
    )

    static var description = IntentDescription(.init(
        "app_intents.watch_assist.description",
        defaultValue: "Opens Assist using the pipeline configured for the watch"
    ))

    static var openAppWhenRun: Bool = true
    // `openAppWhenRun` is deprecated from watchOS 26; both stay until the deployment target passes 26.
    @available(watchOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        WatchAssistLaunch.requestConfigured()
        #endif
        return .result()
    }
}
