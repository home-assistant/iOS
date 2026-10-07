import AppIntents
import CoreSpotlight
import Foundation
import Shared

@available(iOS 18.0, *)
extension HACalendarAppEntity: IndexedEntity {
    /// Mirrors `HAAppEntityAppIntentEntity`: Spotlight renders `contentDescription` as the second row
    /// and does not fall back to the display representation's subtitle, so the entity id is set there
    /// explicitly.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = entityId
        attributes.keywords = searchKeywords
        attributes.alternateNames = contextualNames
        return attributes
    }

    /// Terms that should find the calendar even though they aren't part of its name: the server it
    /// lives on, and the entity id both as written and spelled out (`calendar.family_events` also
    /// matches "family events").
    private var searchKeywords: [String] {
        Self.deduplicated([
            serverName,
            entityId,
            entityId.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " "),
        ])
    }

    /// The name paired with its server, in both orders, so "Family calendar home" matches a single
    /// field rather than relying on Spotlight to combine a name hit with a keyword hit.
    private var contextualNames: [String] {
        Self.deduplicated([serverName])
            .flatMap { ["\(name) \($0)", "\($0) \(name)"] }
    }

    private static func deduplicated(_ terms: [String?]) -> [String] {
        var seen = Set<String>()
        return terms
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
