import AppIntents
import Foundation

/// Shortcuts offered to Siri and Spotlight on install; phrases are localized in `AppShortcuts.strings`.
/// Gated at iOS 17 because `PerformActionAppIntent` and `GetCameraSnapshotAppIntent` are.
@available(iOS 17.0, *)
struct HomeAssistantAppShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .lightBlue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnOffEntityAppIntent(action: .on),
            phrases: [
                "\(.applicationName) turn on \(\.$entity)",
                "Turn on \(\.$entity) in \(.applicationName)",
                "Turn something on in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.turn_on.title", defaultValue: "Turn On"),
            systemImageName: "power"
        )
        AppShortcut(
            intent: TurnOnOffEntityAppIntent(action: .off),
            phrases: [
                "\(.applicationName) turn off \(\.$entity)",
                "Turn off \(\.$entity) in \(.applicationName)",
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
        // The same thing tapping a Spotlight result does: open the entity's more-info dialog. "Open"
        // is listed with and without "details" so the word is optional; on a cover that bare wording
        // also matches the open shortcut below, and Siri picks between the two.
        AppShortcut(
            intent: ShowEntityDetailsAppIntent(),
            phrases: [
                "\(.applicationName) show \(\.$target)",
                "Show \(\.$target) in \(.applicationName)",
                "Open \(\.$target) in \(.applicationName)",
                "Open \(\.$target) details in \(.applicationName)",
                "Show something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.show_entity.title", defaultValue: "Show Entity"),
            systemImageName: "arrow.up.forward.app"
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
        // Open and close are two shortcuts rather than one with the verb as a parameter: a phrase
        // may interpolate only a single parameter, and the entity is the one worth naming out loud.
        AppShortcut(
            intent: OpenCloseEntityAppIntent(action: .open),
            phrases: [
                "\(.applicationName) open \(\.$entity)",
                "Open \(\.$entity) in \(.applicationName)",
                "Open something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.open.title", defaultValue: "Open"),
            systemImageName: "curtains"
        )
        AppShortcut(
            intent: OpenCloseEntityAppIntent(action: .close),
            phrases: [
                "\(.applicationName) close \(\.$entity)",
                "Close \(\.$entity) in \(.applicationName)",
                "Close something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.close.title", defaultValue: "Close"),
            systemImageName: "curtains.closed"
        )
    }
}
