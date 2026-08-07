import AppIntents
import Foundation
import Shared

/// One of the user's circular watch complications, offered to the gauge widget's complication source.
/// `id` is the `WatchComplicationConfig` id.
///
/// Circular only: the gauge widget renders the circular complication style, so only complications laid
/// out for that family are offered.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetCircularComplicationAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.parameters.complication", defaultValue: "Complication")
    )
    static let defaultQuery = WidgetCircularComplicationAppEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(config: WatchComplicationConfig) {
        self.init(id: config.id, name: config.displayName)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetCircularComplicationAppEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetCircularComplicationAppEntity] {
        WidgetComplicationResolver.configs(family: .circular)
            .filter { identifiers.contains($0.id) }
            .map(WidgetCircularComplicationAppEntity.init(config:))
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetCircularComplicationAppEntity> {
        .init(items: WidgetComplicationResolver.configs(family: .circular)
            .map(WidgetCircularComplicationAppEntity.init(config:)))
    }
}
