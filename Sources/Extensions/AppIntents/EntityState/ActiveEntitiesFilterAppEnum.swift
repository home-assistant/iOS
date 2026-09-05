import AppIntents
import Foundation
import Shared

/// The kinds of entity "what is on" can ask about. Raw values are persisted in saved shortcuts, so
/// they are fixed: append cases, never rename or reorder them.
@available(macOS 13.0, *)
enum ActiveEntitiesFilterAppEnum: String, Codable, Sendable, AppEnum {
    case all = "all"
    case light = "light"
    case switchEntity = "switch"
    case fan = "fan"
    case cover = "cover"
    case lock = "lock"
    case mediaPlayer = "media_player"
    case climate = "climate"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.active_entities.filter.name",
        defaultValue: "Kind"
    ))

    /// Plural nouns, because every phrase and dialog reads "What lights are on".
    static let caseDisplayRepresentations: [ActiveEntitiesFilterAppEnum: DisplayRepresentation] = [
        .all: .init(title: .init("app_intents.active_entities.filter.all", defaultValue: "entities")),
        .light: .init(title: .init("app_intents.active_entities.filter.lights", defaultValue: "lights")),
        .switchEntity: .init(title: .init("app_intents.active_entities.filter.switches", defaultValue: "switches")),
        .fan: .init(title: .init("app_intents.active_entities.filter.fans", defaultValue: "fans")),
        .cover: .init(title: .init("app_intents.active_entities.filter.covers", defaultValue: "covers")),
        .lock: .init(title: .init("app_intents.active_entities.filter.locks", defaultValue: "locks")),
        .mediaPlayer: .init(
            title: .init("app_intents.active_entities.filter.media_players", defaultValue: "media players")
        ),
        .climate: .init(title: .init("app_intents.active_entities.filter.climates", defaultValue: "thermostats")),
    ]

    /// The domains this filter reads. `all` covers everything a person would call "on".
    var domains: [Domain] {
        switch self {
        case .all: Domain.voiceReadable
        case .light: [.light]
        case .switchEntity: [.switch, .inputBoolean]
        case .fan: [.fan]
        case .cover: [.cover]
        case .lock: [.lock]
        case .mediaPlayer: [.mediaPlayer]
        case .climate: [.climate]
        }
    }

    /// Covers and locks read as open rather than on, so the answer uses their wording.
    var readsAsOpen: Bool {
        self == .cover || self == .lock
    }
}
