import AppIntents

/// Lists the servers the energy complication can summarise, straight from the app group.
@available(watchOS 10.0, *)
struct WatchEnergyServerEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [WatchEnergyServerEntity.ID]) async throws -> [WatchEnergyServerEntity] {
        entities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<WatchEnergyServerEntity> {
        .init(items: entities().filter { string.isEmpty || $0.name.localizedCaseInsensitiveContains(string) })
    }

    func suggestedEntities() async throws -> IntentItemCollection<WatchEnergyServerEntity> {
        .init(items: entities())
    }

    func defaultResult() async -> WatchEnergyServerEntity? {
        entities().first
    }

    private func entities() -> [WatchEnergyServerEntity] {
        WatchEnergyComplicationStore.snapshots().map(WatchEnergyServerEntity.init(snapshot:))
    }
}
