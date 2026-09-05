import AppIntents
import Foundation

/// Shortcuts offered to Siri and Spotlight on install; phrases are localized in `AppShortcuts.strings`.
/// Gated at iOS 17 because `PerformActionAppIntent` and `GetCameraSnapshotAppIntent` are.
@available(iOS 17.0, *)
struct HomeAssistantAppShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .lightBlue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SceneAppIntent(),
            phrases: [
                "Activate \(\.$scene) in \(.applicationName)",
                "Activate the \(\.$scene) scene in \(.applicationName)",
                "Activate a scene in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.activate_scene.title", defaultValue: "Activate Scene"),
            systemImageName: "moon.stars"
        )
        AppShortcut(
            intent: TurnOnEntityAppIntent(),
            phrases: [
                "Turn on \(\.$entity) in \(.applicationName)",
                "Open \(\.$entity) in \(.applicationName)",
                "Turn something on in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.turn_on.title", defaultValue: "Turn On"),
            systemImageName: "power"
        )
        AppShortcut(
            intent: TurnOffEntityAppIntent(),
            phrases: [
                "Turn off \(\.$entity) in \(.applicationName)",
                "Close \(\.$entity) in \(.applicationName)",
                "Turn something off in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.turn_off.title", defaultValue: "Turn Off"),
            systemImageName: "power"
        )
        AppShortcut(
            intent: GetEntityStateAppIntent(),
            phrases: [
                "Check an entity in \(.applicationName)",
                "Get an entity state from \(.applicationName)",
                "Is \(\.$entity) on in \(.applicationName)",
                "What is the state of \(\.$entity) in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.get_entity_state.title", defaultValue: "Get Entity State"),
            systemImageName: "info.circle"
        )
        AppShortcut(
            intent: AssistPromptAppIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) Assist",
                "Talk to \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.ask_assist.title", defaultValue: "Ask Assist"),
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: GetActiveEntitiesAppIntent(),
            phrases: [
                "What \(\.$filter) are on in \(.applicationName)",
                "Which \(\.$filter) are on in \(.applicationName)",
                "What is on in \(.applicationName)",
                "What is still on in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.what_is_on.title", defaultValue: "What Is On"),
            systemImageName: "lightbulb"
        )
    }
}
