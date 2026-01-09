import Combine
import Foundation
import HAKit
import Shared

// MARK: - Entity State Provider

/// Provides real-time entity state data from Home Assistant for screensaver display
@MainActor
public final class EntityStateProvider: ObservableObject {
    // MARK: - Singleton

    public static let shared = EntityStateProvider()

    // MARK: - Published State

    /// Current entity states keyed by entity ID
    @Published public private(set) var entityStates: [String: EntityState] = [:]

    /// Whether we're currently connected to HA
    @Published public private(set) var isConnected: Bool = false

    // MARK: - Private

    private var subscriptionToken: HACancellable?
    private var watchedEntityIds: Set<String> = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start watching specific entities for state changes
    public func watchEntities(_ entityIds: [String]) {
        let newIds = Set(entityIds)
        guard newIds != watchedEntityIds else { return }

        watchedEntityIds = newIds
        subscribeToEntities()
    }

    /// Get the current state for an entity
    public func state(for entityId: String) -> EntityState? {
        entityStates[entityId]
    }

    /// Stop watching all entities
    public func stopWatching() {
        subscriptionToken?.cancel()
        subscriptionToken = nil
        watchedEntityIds.removeAll()
        entityStates.removeAll()
        isConnected = false
    }

    // MARK: - Private Methods

    private func subscribeToEntities() {
        subscriptionToken?.cancel()

        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.warning("No HA server available for entity subscription")
            isConnected = false
            return
        }

        Current.Log.info("Subscribing to \(watchedEntityIds.count) entities for screensaver")

        subscriptionToken = api.connection.caches.states().subscribe { [weak self] _, states in
            Task { @MainActor [weak self] in
                guard let self else { return }

                self.isConnected = true

                // Update only the entities we're watching
                var newStates: [String: EntityState] = [:]
                for entityId in self.watchedEntityIds {
                    if let haEntity = states.all.first(where: { $0.entityId == entityId }) {
                        newStates[entityId] = EntityState(from: haEntity)
                    }
                }
                self.entityStates = newStates
            }
        }
    }
}

// MARK: - Entity State Model

/// Simplified entity state for display purposes
public struct EntityState: Identifiable, Equatable {
    public var id: String { entityId }

    public let entityId: String
    public let state: String
    public let friendlyName: String
    public let icon: String?
    public let unitOfMeasurement: String?
    public let lastUpdated: Date?

    /// Formatted display value including unit
    public var displayValue: String {
        if let unit = unitOfMeasurement, !unit.isEmpty {
            return "\(state) \(unit)"
        }
        return state
    }

    /// Just the value without unit
    public var value: String {
        state
    }

    init(from haEntity: HAEntity) {
        self.entityId = haEntity.entityId
        self.state = haEntity.state
        self.friendlyName = haEntity.attributes["friendly_name"] as? String ?? haEntity.entityId
        self.icon = haEntity.attributes["icon"] as? String
        self.unitOfMeasurement = haEntity.attributes["unit_of_measurement"] as? String
        self.lastUpdated = haEntity.lastUpdated
    }

    // For previews
    init(entityId: String, state: String, friendlyName: String, icon: String? = nil, unit: String? = nil) {
        self.entityId = entityId
        self.state = state
        self.friendlyName = friendlyName
        self.icon = icon
        self.unitOfMeasurement = unit
        self.lastUpdated = Date()
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension EntityStateProvider {
    static var preview: EntityStateProvider {
        let provider = EntityStateProvider()
        provider.entityStates = [
            "sensor.temperature": EntityState(
                entityId: "sensor.temperature",
                state: "21.5",
                friendlyName: "Temperature",
                icon: "mdi:thermometer",
                unit: "°C"
            ),
            "sensor.humidity": EntityState(
                entityId: "sensor.humidity",
                state: "45",
                friendlyName: "Humidity",
                icon: "mdi:water-percent",
                unit: "%"
            ),
            "weather.home": EntityState(
                entityId: "weather.home",
                state: "sunny",
                friendlyName: "Weather",
                icon: "mdi:weather-sunny",
                unit: nil
            ),
        ]
        provider.isConnected = true
        return provider
    }
}
#endif
