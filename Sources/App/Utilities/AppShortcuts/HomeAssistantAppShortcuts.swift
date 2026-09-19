import AppIntents
import Foundation

/// Shortcuts offered to Siri and Spotlight on install; phrases are localized in `AppShortcuts.strings`.
/// Gated at iOS 17 because `PerformActionAppIntent` and `GetCameraSnapshotAppIntent` are.
///
/// Every shortcut that names an entity carries a `parameterPresentation`, and that is not optional
/// dressing: the system builds one row per shortcut per entity, and with no presentation to label it
/// each of those rows is titled with nothing but the entity's own name. Searching for a light turned
/// up half a dozen rows all reading "Chamber light", one of which dimmed it, one turned it off and one
/// opened the app. The summary is what writes the verb into the row, so "Turn off Chamber light" and
/// "Dim Chamber light" are told apart before they are tapped rather than after.
///
/// The summaries are phrased the way that language's spoken phrases already are — they share the
/// `AppShortcuts.strings` table with them — so a row reads like the sentence that runs it.
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
            systemImageName: "power",
            parameterPresentation: ParameterPresentation(
                for: \.$entity,
                summary: Summary("Turn on \(\.$entity)"),
                optionsCollections: {
                    OptionsCollection(
                        ControllableEntityAppEntityQuery(),
                        title: .init("app_intents.controllable_entity.parameter.entity", defaultValue: "Entity"),
                        systemImageName: "power"
                    )
                }
            )
        )
        AppShortcut(
            intent: TurnOnOffEntityAppIntent(action: .off),
            phrases: [
                "\(.applicationName) turn off \(\.$entity)",
                "Turn off \(\.$entity) in \(.applicationName)",
                "Turn something off in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.turn_off.title", defaultValue: "Turn Off"),
            systemImageName: "power",
            parameterPresentation: ParameterPresentation(
                for: \.$entity,
                summary: Summary("Turn off \(\.$entity)"),
                optionsCollections: {
                    OptionsCollection(
                        ControllableEntityAppEntityQuery(),
                        title: .init("app_intents.controllable_entity.parameter.entity", defaultValue: "Entity"),
                        systemImageName: "power"
                    )
                }
            )
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
            systemImageName: "info.circle",
            parameterPresentation: ParameterPresentation(
                for: \.$entity,
                summary: Summary("Is \(\.$entity) on"),
                optionsCollections: {
                    OptionsCollection(
                        ReadableEntityAppEntityQuery(),
                        title: .init("app_intents.entity_state.parameter.entity", defaultValue: "Entity"),
                        systemImageName: "info.circle"
                    )
                }
            )
        )
        // The same thing tapping a Spotlight result does: open the entity's more-info dialog. "Open"
        // alone belongs to the cover shortcut below, so the phrases lead with "show" and spell out
        // "details" where they use the verb, rather than leaving Siri two readings of "open the blind".
        // The summary spells it out for the same reason: it is the one row that opens the app rather
        // than changing anything, and next to "Open <cover>" that has to be legible at a glance.
        AppShortcut(
            intent: ShowEntityDetailsAppIntent(),
            phrases: [
                "\(.applicationName) show \(\.$target)",
                "Show \(\.$target) in \(.applicationName)",
                "Open \(\.$target) details in \(.applicationName)",
                "Show something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.show_entity.title", defaultValue: "Show Entity"),
            systemImageName: "arrow.up.forward.app",
            parameterPresentation: ParameterPresentation(
                for: \.$target,
                summary: Summary("Open \(\.$target) details"),
                optionsCollections: {
                    OptionsCollection(
                        ReadableEntityOptionsProvider(),
                        title: .init("app_intents.show_entity_details.parameter.entity", defaultValue: "Entity"),
                        systemImageName: "arrow.up.forward.app"
                    )
                }
            )
        )
        AppShortcut(
            intent: SetTemperatureAppIntent(),
            phrases: [
                "\(.applicationName) set a temperature",
                "Set a temperature in \(.applicationName)",
                "Set \(\.$entity) temperature in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.set_temperature.title", defaultValue: "Set Temperature"),
            systemImageName: "thermometer",
            parameterPresentation: ParameterPresentation(
                for: \.$entity,
                summary: Summary("Set \(\.$entity) temperature"),
                optionsCollections: {
                    OptionsCollection(
                        ThermostatAppEntityQuery(),
                        title: .init("app_intents.set_temperature.parameter.entity", defaultValue: "Thermostat"),
                        systemImageName: "thermometer"
                    )
                }
            )
        )
        AppShortcut(
            intent: SetBrightnessAppIntent(),
            phrases: [
                "\(.applicationName) dim \(\.$light)",
                "Set a brightness in \(.applicationName)",
                "Dim \(\.$light) in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.set_brightness.title", defaultValue: "Set Brightness"),
            systemImageName: "sun.max",
            parameterPresentation: ParameterPresentation(
                for: \.$light,
                summary: Summary("Dim \(\.$light)"),
                optionsCollections: {
                    OptionsCollection(
                        DimmableLightAppEntityQuery(),
                        title: .init("app_intents.lights.light.title", defaultValue: "Light"),
                        systemImageName: "sun.max"
                    )
                }
            )
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
            systemImageName: "curtains",
            parameterPresentation: ParameterPresentation(
                for: \.$entity,
                summary: Summary("Open \(\.$entity)"),
                optionsCollections: {
                    OptionsCollection(
                        OpenableEntityAppEntityQuery(),
                        title: .init("app_intents.open_close.entity.name", defaultValue: "Cover"),
                        systemImageName: "curtains"
                    )
                }
            )
        )
        AppShortcut(
            intent: OpenCloseEntityAppIntent(action: .close),
            phrases: [
                "\(.applicationName) close \(\.$entity)",
                "Close \(\.$entity) in \(.applicationName)",
                "Close something in \(.applicationName)",
            ],
            shortTitle: .init("app_shortcuts.close.title", defaultValue: "Close"),
            systemImageName: "curtains.closed",
            parameterPresentation: ParameterPresentation(
                for: \.$entity,
                summary: Summary("Close \(\.$entity)"),
                optionsCollections: {
                    OptionsCollection(
                        OpenableEntityAppEntityQuery(),
                        title: .init("app_intents.open_close.entity.name", defaultValue: "Cover"),
                        systemImageName: "curtains.closed"
                    )
                }
            )
        )
    }
}
