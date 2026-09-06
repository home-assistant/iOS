import AppIntents
import Foundation

/// Shortcuts offered to Siri and Spotlight on install; phrases are localized in `AppShortcuts.strings`.
/// Gated at iOS 17 because `PerformActionAppIntent` and `GetCameraSnapshotAppIntent` are.
@available(iOS 17.0, *)
struct HomeAssistantAppShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .lightBlue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnEntityAppIntent(),
            phrases: [
                "\(.applicationName) turn on \(\.$entity)",
                "Turn on \(\.$entity) in \(.applicationName)",
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
            intent: OpenCloseEntityAppIntent(),
            // The action is interpolated so one template carries both verbs; the entity list is
            // covers only, because the parameter has its own query.
            phrases: [
                "\(.applicationName) \(\.$action) \(\.$entity)",
                "\(\.$action) \(\.$entity) in \(.applicationName)",
                "Open something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.open_close.title", defaultValue: "Open Or Close"),
            systemImageName: "curtains.closed"
        )
    }
}
