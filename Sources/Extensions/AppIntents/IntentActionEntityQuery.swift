import AppIntents
import Shared

@available(iOS 17.0, watchOS 10.0, *)
struct IntentActionEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<PerformActionAppIntent>(\.$server)
    var intent

    func entities(for identifiers: [String]) async throws -> [IntentActionEntity] {
        let actions = try await actionEntities().flatMap(\.1)
        let matchedActions = actions.filter { identifiers.contains($0.id) }
        let matchedIdentifiers = Set(matchedActions.map(\.id))
        let fallbackActions = identifiers
            .filter { matchedIdentifiers.contains($0) == false }
            .compactMap(IntentActionEntity.init(identifier:))
        return matchedActions + fallbackActions
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentActionEntity> {
        try await actionCollection(matching: string)
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentActionEntity> {
        try await actionCollection()
    }

    private func actionCollection(matching string: String? = nil) async throws
        -> IntentItemCollection<IntentActionEntity> {
        let sections = try await actionEntities().map { server, actions in
            let filteredActions: [IntentActionEntity]
            if let string, string.isEmpty == false {
                filteredActions = actions.filter {
                    $0.displayName.localizedCaseInsensitiveContains(string)
                        || $0.actionId.localizedCaseInsensitiveContains(string)
                        || $0.translationKey?.localizedCaseInsensitiveContains(string) == true
                }
            } else {
                filteredActions = actions
            }
            return IntentItemSection<IntentActionEntity>(
                .init(stringLiteral: server.info.name),
                items: filteredActions
            )
        }
        return .init(sections: sections)
    }

    private func actionEntities() async throws -> [(Server, [IntentActionEntity])] {
        guard let server = intent?.server.getServer() else {
            return []
        }

        let definitions = try await AppIntentServerAPI.actionDefinitions(server: server)
        return [(
            server,
            definitions.map { definition in
                IntentActionEntity(serverId: server.identifier.rawValue, definition: definition)
            }
        )]
    }
}
