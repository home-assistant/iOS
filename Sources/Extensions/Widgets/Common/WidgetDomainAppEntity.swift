import AppIntents
import Foundation
import Shared

/// A Home Assistant domain as offered in a widget configuration's domain pickers.
///
/// `id` is the domain identifier ("light", "media_player") — the same value an entity id is
/// prefixed with, which is what the widget matches against when filtering.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDomainAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.parameters.domain", defaultValue: "Domain")
    )
    static let defaultQuery = WidgetDomainAppEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: name))
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(domain: Domain) {
        self.init(id: domain.rawValue, name: domain.name)
    }
}
