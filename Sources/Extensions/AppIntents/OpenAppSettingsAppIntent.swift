import AppIntents
import Shared

@available(iOS 16.4, *)
struct OpenAppSettingsAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.open_app_settings.title",
        defaultValue: "Open app settings"
    )

    static var description = IntentDescription(.init(
        "app_intents.open_app_settings.description",
        defaultValue: "Opens the companion app directly in its settings"
    ))

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            Current.sceneManager.appCoordinator.done { coordinator in
                coordinator.showSettings()
            }
        }
        return .result()
    }
}
