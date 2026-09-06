import CoreSpotlight
import Foundation
import Shared

/// Indexes cached calendar events so Spotlight can find them by title.
///
/// Kept apart from `SpotlightEntityIndexer` rather than folded into its snapshot: the event entity
/// is iOS 27, and storing one on that type would raise the whole indexer — and everything it
/// touches — to iOS 27 as well.
///
/// Only events are indexed here. Calendars and to-do lists already reach Spotlight through
/// `HACalendarAppEntity` and `HAAppEntityAppIntentEntity`, so indexing their schema counterparts
/// would put the same thing in the index twice.
@available(iOS 27.0, *)
enum CalendarEventSpotlightIndexer {
    private static let stateKey = "spotlightIndexedCalendarEventIds"
    private static let batchSize = 100

    /// Replaces the indexed events with what the cache currently holds.
    ///
    /// The cache is a rolling window that drops events a month after they end, so entries that fell
    /// out of it are removed here rather than lingering in Spotlight forever.
    static func reindex(index: CSSearchableIndex, defaults: UserDefaults?) async {
        let events = await (try? CalendarEventSchemaEntityQuery().suggestedEntities()) ?? []
        let ids = events.map(\.id)
        let stale = Set(defaults?.stringArray(forKey: stateKey) ?? []).subtracting(ids)

        do {
            if !stale.isEmpty {
                try await index.deleteAppEntities(
                    identifiedBy: Array(stale),
                    ofType: CalendarEventSchemaEntity.self
                )
            }
            for batch in stride(from: 0, to: events.count, by: batchSize) {
                guard !Task.isCancelled else { return }
                let upperBound = min(batch + batchSize, events.count)
                try await index.indexAppEntities(Array(events[batch ..< upperBound]))
            }
            defaults?.set(ids, forKey: stateKey)
            Current.Log.info("Spotlight calendar event index updated: \(ids.count) events, \(stale.count) removed")
        } catch {
            Current.Log.error("Failed to update Spotlight calendar event index: \(error.localizedDescription)")
        }
    }
}
