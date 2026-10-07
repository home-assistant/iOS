import AppIntents
import Foundation
import Shared

/// An attribute of the gauge widget's picked entity. Selecting one makes the gauge read that
/// attribute's value instead of the entity state (mirrors the watch complication builder). `id`
/// is the attribute key.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetGaugeAttributeAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.parameters.attribute", defaultValue: "Attribute")
    )
    static let defaultQuery = WidgetGaugeAttributeAppEntityQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }

    init(id: String) {
        self.id = id
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetGaugeAttributeAppEntityQuery: EntityQuery {
    @IntentParameterDependency<WidgetGaugeAppIntent>(\.$entity)
    var config

    func entities(for identifiers: [String]) async throws -> [WidgetGaugeAttributeAppEntity] {
        identifiers.map { WidgetGaugeAttributeAppEntity(id: $0) }
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetGaugeAttributeAppEntity> {
        await .init(
            items: WidgetEntityAttributes.keys(for: config?.entity)
                .map { WidgetGaugeAttributeAppEntity(id: $0) }
        )
    }
}
