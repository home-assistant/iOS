import AppIntents
import Foundation
import Shared

/// Offers every domain the app models for the widget configuration's domain pickers, ordered by
/// localized name so the list reads the way the picker displays it.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDomainAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetDomainAppEntity] {
        identifiers.map { identifier in
            // A domain the app does not model (yet) still has to resolve, otherwise a saved
            // configuration would silently drop it and change what the widget shows.
            Domain(rawValue: identifier).map(WidgetDomainAppEntity.init(domain:))
                ?? WidgetDomainAppEntity(id: identifier, name: identifier)
        }
    }

    /// Matches the localized name as well as the identifier, so both "Light" and "light" resolve.
    func entities(matching string: String) async throws -> IntentItemCollection<WidgetDomainAppEntity> {
        .init(items: Self.allDomains.filter { domain in
            domain.name.localizedCaseInsensitiveContains(string)
                || domain.id.localizedCaseInsensitiveContains(string)
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<WidgetDomainAppEntity> {
        .init(items: Self.allDomains)
    }

    private static var allDomains: [WidgetDomainAppEntity] {
        Domain.allCases
            .map(WidgetDomainAppEntity.init(domain:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
