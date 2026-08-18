import AppIntents
import CoreSpotlight
import Foundation
import Shared

/// Keeps the system's index of `HACalendarAppEntity` in step with the stored calendars.
///
/// Indexing is what makes the calendars discoverable to Siri and Apple Intelligence: the entities
/// are matched semantically against what the user says, so "my family calendar" resolves without an
/// exact string match. The index is refreshed whenever the app database update routine finishes,
/// which is the point at which `HACalendar` rows can have changed.
final class HACalendarSpotlightIndexer {
    static let shared = HACalendarSpotlightIndexer()

    private var observer: NSObjectProtocol?
    /// Serializes index writes so overlapping refreshes (one per server) can't interleave and leave
    /// the index describing a mix of two snapshots.
    private var indexTask: Task<Void, Never>?

    func start() {
        guard #available(iOS 18, *), observer == nil else { return }
        // Main queue on purpose: the update routine posts from a background task, and `indexTask` is
        // only safe to hand off from one place.
        observer = NotificationCenter.default.addObserver(
            forName: .appDatabaseUpdaterDidFinishRoutine,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard #available(iOS 18, *) else { return }
            self?.scheduleIndexUpdate()
        }
        scheduleIndexUpdate()
    }

    @available(iOS 18, *)
    private func scheduleIndexUpdate() {
        let previous = indexTask
        indexTask = Task.detached(priority: .utility) {
            await previous?.value
            await Self.updateIndex()
        }
    }

    @available(iOS 18, *)
    private static func updateIndex() async {
        let entities = HACalendar.all().map(HACalendarAppEntity.init(calendar:))
        do {
            // Delete first so calendars the user removed in Home Assistant stop being suggested;
            // `indexAppEntities` only ever adds or updates.
            try await CSSearchableIndex.default().deleteAppEntities(ofType: HACalendarAppEntity.self)
            guard !entities.isEmpty else { return }
            try await CSSearchableIndex.default().indexAppEntities(entities)
            Current.Log.verbose("Indexed \(entities.count) calendars for Siri and Spotlight")
        } catch {
            Current.Log.error("Failed to index calendars for Siri and Spotlight: \(error)")
        }
    }
}
