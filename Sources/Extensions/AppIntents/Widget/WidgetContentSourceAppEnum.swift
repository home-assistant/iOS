import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetContentSourceAppEnum: String, Codable, Sendable, AppEnum {
    /// The widget picks a single entity and its value is generated automatically from the entity's state.
    case entity

    /// The widget mirrors one of the watch complications the user already built, rendered by the very
    /// same views the watch and the complication editor use.
    case complication

    /// The user provides Jinja templates rendered by the server (requires an admin user).
    case template

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.content_source.title", defaultValue: "Source")
    )
    static var caseDisplayRepresentations: [WidgetContentSourceAppEnum: DisplayRepresentation] = [
        .entity: DisplayRepresentation(title: .init("widgets.content_source.entity", defaultValue: "Entity")),
        .complication: DisplayRepresentation(title: .init(
            "widgets.content_source.complication",
            defaultValue: "Complication"
        )),
        .template: DisplayRepresentation(title: .init("widgets.content_source.template", defaultValue: "Template")),
    ]
}
