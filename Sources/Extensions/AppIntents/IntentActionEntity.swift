import AppIntents
import SFSafeSymbols
import Shared

@available(iOS 17.0, watchOS 10.0, *)
struct IntentActionEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
    static let defaultQuery = IntentActionEntityQuery()

    let id: String
    let serverId: String
    let actionId: String
    let displayName: String
    let actionDescription: String?
    let translationKey: String?
    let icon: String?
    /// Whether the underlying action returns a response (`SupportsResponse.OPTIONAL` / `.ONLY`).
    let supportsResponse: Bool

    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: displayName),
            subtitle: .init(stringLiteral: subtitle),
            image: displayRepresentationImage
        )
    }

    private var subtitle: String {
        [actionId, actionDescription]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: " - ")
    }

    private var displayRepresentationImage: DisplayRepresentation.Image {
        guard let data = icon.flatMap(MaterialDesignIcons.pngData(forServersideValue:)) else {
            return .init(systemName: SFSymbol.bolt.rawValue)
        }
        return .init(data: data, isTemplate: true)
    }

    init(serverId: String, definition: IntentActionDefinition) {
        self.id = "\(serverId)::\(definition.actionId)"
        self.serverId = serverId
        self.actionId = definition.actionId
        self.displayName = definition.displayName
        self.actionDescription = definition.displayDescription
        self.translationKey = definition.translationKey
        self.icon = definition.icon
        self.supportsResponse = definition.supportsResponse
    }

    /// Rebuilds an entity from a persisted `serverId::domain.service` identifier, for when the
    /// server can no longer be reached to describe it.
    init?(identifier: String) {
        let components = identifier.components(separatedBy: "::")
        guard components.count == 2 else {
            return nil
        }

        self.id = identifier
        self.serverId = components[0]
        self.actionId = components[1]
        self.displayName = components[1]
        self.actionDescription = nil
        self.translationKey = nil
        self.icon = nil
        self.supportsResponse = false
    }
}
