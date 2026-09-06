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
                "\(.applicationName) activate \(\.$scene)",
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
                "\(.applicationName) turn on \(\.$entity)",
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
                "\(.applicationName) turn off \(\.$entity)",
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
                "\(.applicationName) is \(\.$entity) on",
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
                "\(.applicationName) assist",
                "Ask \(.applicationName)",
                "Ask \(.applicationName) Assist",
                "Talk to \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.ask_assist.title", defaultValue: "Ask Assist"),
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: LockEntityAppIntent(),
            phrases: [
                "\(.applicationName) lock \(\.$entity)",
                "Lock \(\.$entity) in \(.applicationName)",
                "Lock something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.lock.title", defaultValue: "Lock"),
            systemImageName: "lock"
        )
        AppShortcut(
            intent: SetTemperatureAppIntent(),
            phrases: [
                "\(.applicationName) set a temperature",
                "Set a temperature in \(.applicationName)",
                "Set \(\.$entity) temperature in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.set_temperature.title", defaultValue: "Set Temperature"),
            systemImageName: "thermometer"
        )
        AppShortcut(
            intent: SetBrightnessAppIntent(),
            phrases: [
                "\(.applicationName) dim \(\.$light)",
                "Set a brightness in \(.applicationName)",
                "Dim \(\.$light) in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.set_brightness.title", defaultValue: "Set Brightness"),
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: GetActiveEntitiesAppIntent(),
            // Only the kind is interpolated: `state` stays at its `.on` default so voice offers the
            // two questions worth asking out loud. "On" and "open" are the same query, so both
            // wordings are spelled out rather than expanded from the state parameter — asking what
            // is *off* would read back nearly every entity in the home, and the specific case
            // ("is the porch light off") is what `GetEntityStateAppIntent` already answers.
            phrases: [
                "\(.applicationName) what \(\.$filter) are on",
                "What \(\.$filter) are on in \(.applicationName)",
                "What \(\.$filter) are open in \(.applicationName)",
                "What is on in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.what_is_on.title", defaultValue: "What Is On"),
            systemImageName: "lightbulb"
        )
    }
}
