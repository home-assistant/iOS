import Foundation

/// A whole area's worth of one kind of thing — "Living room lights" — as something a spoken command
/// can act on.
///
/// Home Assistant scopes an area target by the calling service's own domain, so `light.turn_on`
/// against an area reaches that area's lights and leaves its television alone. That is what lets one
/// target stand in for a room without the command becoming a blunt instrument.
public struct AreaTarget: Hashable, Sendable {
    public let areaId: String
    public let areaName: String
    public let domain: Domain
    /// Set only when every entity behind the target shares one, so a room of curtains reads as
    /// "curtains" rather than by the domain's own broader word for them.
    public let deviceClass: DeviceClass?
    /// The area's own aliases from Home Assistant, which people set precisely so a voice assistant
    /// recognises the room by the name they actually say.
    public let aliases: [String]

    public init(
        areaId: String,
        areaName: String,
        domain: Domain,
        deviceClass: DeviceClass? = nil,
        aliases: [String] = []
    ) {
        self.areaId = areaId
        self.areaName = areaName
        self.domain = domain
        self.deviceClass = deviceClass
        self.aliases = aliases
    }

    /// Whether a spoken or typed search names this target. Matched against the area on its own as
    /// well as the full name, so "living room" finds it and so does "living room lights".
    public func matches(_ query: String) -> Bool {
        let needle = query.foldedForSearch
        guard !needle.isEmpty else { return true }
        return ([displayName, areaName] + aliases).contains { $0.foldedForSearch.contains(needle) }
    }

    /// The domains worth offering a whole area of at once.
    ///
    /// A group is already a bulk target, and a scene, script or button is a single thing that runs
    /// rather than a roomful of things that switch, so none of them gain anything from an area.
    public static let bulkDomains: [Domain] = [
        .light,
        .switch,
        .inputBoolean,
        .fan,
        .climate,
        .mediaPlayer,
        .humidifier,
        .cover,
        .valve,
    ]

    /// The id a saved shortcut stores, namespaced away from an entity's `serverId-entityId` so the
    /// two can never collide. Adding ids is safe; this one must not change once it has shipped.
    public func id(serverId: String) -> String {
        "\(serverId)-area:\(areaId):\(domain.rawValue)"
    }

    /// What the target is called out loud and in the picker, e.g. "Living room lights".
    public var displayName: String {
        switch deviceClass {
        case .curtain: return L10n.AppIntents.AreaTarget.curtains(areaName)
        case .blind: return L10n.AppIntents.AreaTarget.blinds(areaName)
        case .shade: return L10n.AppIntents.AreaTarget.shades(areaName)
        case .garage, .garageDoor: return L10n.AppIntents.AreaTarget.garageDoors(areaName)
        case .door: return L10n.AppIntents.AreaTarget.doors(areaName)
        case .window: return L10n.AppIntents.AreaTarget.windows(areaName)
        case .shutter: return L10n.AppIntents.AreaTarget.shutters(areaName)
        default: break
        }

        switch domain {
        case .light: return L10n.AppIntents.AreaTarget.lights(areaName)
        case .switch: return L10n.AppIntents.AreaTarget.switches(areaName)
        case .inputBoolean: return L10n.AppIntents.AreaTarget.toggles(areaName)
        case .fan: return L10n.AppIntents.AreaTarget.fans(areaName)
        case .climate: return L10n.AppIntents.AreaTarget.thermostats(areaName)
        case .mediaPlayer: return L10n.AppIntents.AreaTarget.mediaPlayers(areaName)
        case .humidifier: return L10n.AppIntents.AreaTarget.humidifiers(areaName)
        case .valve: return L10n.AppIntents.AreaTarget.valves(areaName)
        default: return L10n.AppIntents.AreaTarget.covers(areaName)
        }
    }

    /// The icon the picker draws, standing for the kind rather than any one entity in it.
    public var iconName: String {
        domain.sfSymbolName
    }
}

public extension [HAAppEntity] {
    /// One target per area and domain, built from the entities a command already offers.
    ///
    /// Taking the entities as they arrive means a target inherits every filter that got them here:
    /// a server the user has kept out of Siri contributes no areas, and neither do hidden or
    /// diagnostic entities. An area with a single light still gets one, because "turn on the
    /// kitchen lights" is how people speak whether the kitchen holds one lamp or five.
    func areaTargets(in areas: [AppArea], domains: [Domain]) -> [AreaTarget] {
        let offered = Set(domains).intersection(AreaTarget.bulkDomains)
        guard !offered.isEmpty else { return [] }

        let byArea = Dictionary(grouping: self) { entity in entity.entityId }
        return areas.flatMap { area -> [AreaTarget] in
            let members = area.entities.compactMap { byArea[$0]?.first }
            return offered.compactMap { domain -> AreaTarget? in
                let matching = members.filter { $0.domain == domain.rawValue }
                guard !matching.isEmpty else { return nil }
                return AreaTarget(
                    areaId: area.areaId,
                    areaName: area.name,
                    domain: domain,
                    deviceClass: matching.sharedDeviceClass,
                    aliases: area.aliases
                )
            }
            .sorted { $0.domain.rawValue < $1.domain.rawValue }
        }
        .sorted { ($0.areaName, $0.domain.rawValue) < ($1.areaName, $1.domain.rawValue) }
    }

    /// The device class every entity here carries, when they all carry the same one. A room whose
    /// covers are half curtains and half blinds has no single word, so it keeps the domain's.
    var sharedDeviceClass: DeviceClass? {
        let classes = Set(compactMap(\.rawDeviceClass))
        guard classes.count == 1, let raw = classes.first else { return nil }
        return DeviceClass(rawValue: raw)
    }
}

private extension String {
    /// Case- and diacritic-insensitive form, so "Escritorio" finds "Escritório".
    var foldedForSearch: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
