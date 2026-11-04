import AppIntents
import Foundation
import Shared

/// An attribute of the details widget's picked entity. Selecting one makes the lower line read that
/// attribute's value instead of the entity state (mirrors the watch complication builder). `id` is
/// the attribute key.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsAttributeAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.parameters.attribute", defaultValue: "Attribute")
    )
    static let defaultQuery = WidgetDetailsAttributeAppEntityQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }

    init(id: String) {
        self.id = id
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsAttributeAppEntityQuery: EntityQuery {
    @IntentParameterDependency<WidgetDetailsAppIntent>(\.$entity)
    var config

    func entities(for identifiers: [String]) async throws -> [WidgetDetailsAttributeAppEntity] {
        identifiers.map { WidgetDetailsAttributeAppEntity(id: $0) }
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetDetailsAttributeAppEntity> {
        await .init(
            items: WidgetEntityAttributes.keys(for: config?.entity)
                .map { WidgetDetailsAttributeAppEntity(id: $0) }
        )
    }
}
