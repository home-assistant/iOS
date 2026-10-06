import AppIntents
import Foundation

/// Which way to switch an entity. Fixed on the intent by each App Shortcut, since a phrase may
/// name only one parameter and the entity is the one worth saying out loud.
@available(macOS 13.0, watchOS 9.4, *)
enum TurnOnOffActionAppEnum: String, Codable, Sendable, AppEnum {
    case on
    case off
    case toggle

    var runnerAction: ControlEntityIntentRunner.Action {
        switch self {
        case .on: .turnOn
        case .off: .turnOff
        case .toggle: .toggle
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.turn_on_off.action.name",
        defaultValue: "Action"
    ))

    static let caseDisplayRepresentations: [TurnOnOffActionAppEnum: DisplayRepresentation] = [
        .on: .init(title: .init("app_intents.turn_on_off.action.on", defaultValue: "Turn on")),
        .off: .init(title: .init("app_intents.turn_on_off.action.off", defaultValue: "Turn off")),
        .toggle: .init(title: .init("app_intents.turn_on_off.action.toggle", defaultValue: "Toggle")),
    ]
}
