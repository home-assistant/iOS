import AppIntents
import Foundation

/// Shortcuts offered to Siri and Spotlight on install; phrases are localized in `AppShortcuts.strings`.
/// Gated at iOS 17 because `PerformActionAppIntent` and `GetCameraSnapshotAppIntent` are.
@available(iOS 17.0, *)
struct HomeAssistantAppShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .lightBlue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScriptAppIntent(),
            phrases: [
                "Run \(\.$script) in \(.applicationName)",
                "Run the \(\.$script) script in \(.applicationName)",
                "Run a script in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.run_script.title", defaultValue: "Run Script"),
            systemImageName: "play.circle"
        )
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
            intent: AutomationAppIntent(),
            phrases: [
                "Trigger \(\.$automation) in \(.applicationName)",
                "Trigger the \(\.$automation) automation in \(.applicationName)",
                "Trigger an automation in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.trigger_automation.title", defaultValue: "Trigger Automation"),
            systemImageName: "bolt"
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
            intent: ToggleEntityAppIntent(),
            phrases: [
                "Toggle \(\.$entity) in \(.applicationName)",
                "Toggle something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.toggle.title", defaultValue: "Toggle"),
            systemImageName: "switch.2"
        )
        AppShortcut(
            intent: GetEntityStateAppIntent(),
            phrases: [
                "Check an entity in \(.applicationName)",
                "Get an entity state from \(.applicationName)",
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
            intent: GetCameraSnapshotAppIntent(),
            phrases: [
                "Get a camera snapshot from \(.applicationName)",
                "Show me a camera in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.camera_snapshot.title", defaultValue: "Camera Snapshot"),
            systemImageName: "camera"
        )
        AppShortcut(
            intent: PerformActionAppIntent(),
            phrases: [
                "Perform an action in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.perform_action.title", defaultValue: "Perform Action"),
            systemImageName: "wand.and.stars"
        )
    }
}
