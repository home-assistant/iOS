import AppIntents
import Foundation
import Shared

/// One of the user's rectangular watch complications, offered to the details widget's complication
/// source. `id` is the `WatchComplicationConfig` id.
///
/// Rectangular only: the details widget's accessory family is rectangular, so mirroring a complication
/// designed for any other family would render a layout it was never laid out for.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetRectangularComplicationAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.parameters.complication", defaultValue: "Complication")
    )
    static let defaultQuery = WidgetRectangularComplicationAppEntityQuery()

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
struct WidgetRectangularComplicationAppEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetRectangularComplicationAppEntity] {
        WidgetComplicationResolver.configs(family: .rectangular)
            .filter { identifiers.contains($0.id) }
            .map(WidgetRectangularComplicationAppEntity.init(config:))
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetRectangularComplicationAppEntity> {
        let items = WidgetComplicationResolver.configs(family: .rectangular)
            .map(WidgetRectangularComplicationAppEntity.init(config:))
        return .init(items: items)
    }
}
