import AppIntents
import CoreSpotlight
import Foundation
import Shared

@available(iOS 18.0, *)
extension HAAppEntityAppIntentEntity: IndexedEntity {
    /// Augments what App Intents derives from `displayRepresentation` with everything a person might
    /// type, and with the context line, which a search result needs as `contentDescription`: Spotlight
    /// renders that as the second row and does not fall back to the display representation's subtitle.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = subtitle
        attributes.keywords = searchKeywords
        attributes.alternateNames = contextualNames
        attributes.thumbnailData = SpotlightEntityIconRenderer.thumbnailData(iconName: iconName)
        return attributes
    }

    /// Terms that should find the entity even though they aren't part of its name: its context, its
    /// domain, and the entity id both as written and spelled out (`cover.cortina_sala` also matches
    /// "cortina sala").
    private var searchKeywords: [String] {
        Self.deduplicated([
            areaName,
            deviceName,
            floorName,
            serverName,
            Domain(entityId: entityId)?.localizedDescription,
            entityId,
            entityId.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " "),
        ])
    }

    /// The name paired with each piece of its context, in both orders, so a query that mixes the two —
    /// "Light living room" for a "Light" in the living room — matches a single field with the same
    /// weight as the name alone, rather than relying on Spotlight to combine name and keyword hits.
    private var contextualNames: [String] {
        Self.deduplicated([areaName, deviceName, floorName, serverName])
            .flatMap { ["\(displayString) \($0)", "\($0) \(displayString)"] }
    }

    /// Drops empty and repeated terms (a device named after its area is common) while keeping the most
    /// specific ones first, since Spotlight treats earlier entries as more relevant.
    private static func deduplicated(_ terms: [String?]) -> [String] {
        var seen = Set<String>()
        return terms
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
