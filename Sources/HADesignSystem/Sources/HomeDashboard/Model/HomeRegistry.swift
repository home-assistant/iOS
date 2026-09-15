import Foundation

/// Everything the home dashboard's strategies read about a server, in one value: the four registries,
/// the current states, which panels the server has and who is looking at it.
///
/// This is the app's stand-in for the frontend's `hass` object, cut down to what the strategies
/// touch. Being a value type is the point — the translator is a pure function of it, so a dashboard
/// can be generated in a test, in a preview or in a snapshot with no connection anywhere.
public struct HomeRegistry: Equatable, Sendable {
    /// Areas in the order the server returns them, which is the order the user dragged them into.
    public let areas: [HomeArea]
    /// Floors in the server's order.
    public let floors: [HomeFloor]
    public let devices: [HomeDevice]
    public let entities: [HomeEntityRegistration]
    public let states: [HomeEntityState]
    /// The panels the server has, by component name — `"light"`, `"energy"`, `"security"`. A summary
    /// only becomes a link when the panel behind it exists.
    public let panels: Set<String>
    /// Whether the person looking is an administrator. Admin-only affordances (editing areas,
    /// opening a device's settings) hang off this.
    public let isAdmin: Bool
    /// The name to greet, when the dashboard greets anybody.
    public let userName: String?
    /// Whether the server is up. A server that is still starting gets its own view.
    public let serverState: HomeServerState
    /// Whether the energy dashboard has anything to show — a grid source the user configured. The
    /// energy panel existing is not enough: an unconfigured one summarises nothing.
    public let hasEnergyData: Bool

    private let areasById: [String: HomeArea]
    private let floorsById: [String: HomeFloor]
    private let devicesById: [String: HomeDevice]
    private let entitiesById: [String: HomeEntityRegistration]
    private let statesById: [String: HomeEntityState]

    public init(
        areas: [HomeArea] = [],
        floors: [HomeFloor] = [],
        devices: [HomeDevice] = [],
        entities: [HomeEntityRegistration] = [],
        states: [HomeEntityState] = [],
        panels: Set<String> = [],
        isAdmin: Bool = false,
        userName: String? = nil,
        serverState: HomeServerState = .running,
        hasEnergyData: Bool = false
    ) {
        self.areas = areas
        self.floors = floors
        self.devices = devices
        self.entities = entities
        self.states = states
        self.panels = panels
        self.isAdmin = isAdmin
        self.userName = userName
        self.serverState = serverState
        self.hasEnergyData = hasEnergyData
        self.areasById = Dictionary(areas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.floorsById = Dictionary(floors.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.devicesById = Dictionary(devices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.entitiesById = Dictionary(entities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.statesById = Dictionary(states.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func area(_ id: String?) -> HomeArea? {
        id.flatMap { areasById[$0] }
    }

    public func floor(_ id: String?) -> HomeFloor? {
        id.flatMap { floorsById[$0] }
    }

    public func device(_ id: String?) -> HomeDevice? {
        id.flatMap { devicesById[$0] }
    }

    public func entity(_ id: String) -> HomeEntityRegistration? {
        entitiesById[id]
    }

    public func state(_ id: String) -> HomeEntityState? {
        statesById[id]
    }

    /// Every entity id that has a state, in the order the states came in. The strategies filter this
    /// list rather than the registry: an entity without a state has nothing to draw.
    public var allEntityIds: [String] {
        states.map(\.id)
    }

    public func hasPanel(_ component: String) -> Bool {
        panels.contains(component)
    }

    /// The effective area of a device: its own, or its parent's when it has none. The port of core's
    /// `async_get_effective_area_id`.
    public func effectiveAreaId(of device: HomeDevice) -> String? {
        if let areaId = device.areaId {
            return areaId
        }
        guard let parentDeviceId = device.parentDeviceId else {
            return nil
        }
        return self.device(parentDeviceId)?.areaId
    }

    /// Where an entity sits in the home. Mirrors `getEntityContext`: an entity the registry does not
    /// know has no context at all, not even the device its id might suggest.
    public func context(of entityId: String) -> HomeEntityContext {
        guard let entity = entity(entityId) else {
            return .unregistered
        }
        let device = device(entity.deviceId)
        let areaId = entity.areaId ?? device.flatMap(effectiveAreaId(of:))
        let area = area(areaId)
        let floor = floor(area?.floorId)
        return HomeEntityContext(entity: entity, device: device, area: area, floor: floor)
    }
}

public extension HomeRegistry {
    /// The same home with fresh states. States change constantly and the registries barely ever do,
    /// so following a state change means rebuilding this much and no more.
    func updating(states: [HomeEntityState]) -> HomeRegistry {
        HomeRegistry(
            areas: areas,
            floors: floors,
            devices: devices,
            entities: entities,
            states: states,
            panels: panels,
            isAdmin: isAdmin,
            userName: userName,
            serverState: serverState,
            hasEnergyData: hasEnergyData
        )
    }
}
