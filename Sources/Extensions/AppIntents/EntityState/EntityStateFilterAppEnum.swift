import AppIntents
import Foundation

/// Which side of an entity's binary state to list.
///
/// `open`/`closed` are the same two queries worded for covers, not extra behaviour: Home Assistant
/// models both as the same underlying state. Both spellings exist so that "what covers are open"
/// and "what lights are on" are each phrased the way people actually ask them.
@available(macOS 13.0, *)
enum EntityStateFilterAppEnum: String, Codable, Sendable, AppEnum {
    case on
    case off
    case open
    case closed

    /// Whether the case asks for entities that are active, as `EntityStateActive` defines it.
    var wantsActive: Bool {
        switch self {
        case .on, .open: true
        case .off, .closed: false
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.active_entities.state.name",
        defaultValue: "State"
    ))

    static let caseDisplayRepresentations: [EntityStateFilterAppEnum: DisplayRepresentation] = [
        .on: .init(title: .init("app_intents.active_entities.state.on", defaultValue: "on")),
        .off: .init(title: .init("app_intents.active_entities.state.off", defaultValue: "off")),
        .open: .init(title: .init("app_intents.active_entities.state.open", defaultValue: "open")),
        .closed: .init(title: .init("app_intents.active_entities.state.closed", defaultValue: "closed")),
    ]
}
