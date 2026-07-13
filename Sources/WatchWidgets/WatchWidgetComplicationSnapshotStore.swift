import Foundation
import WidgetKit

enum WatchWidgetComplicationSnapshotStore {
    static func complication(
        for widgetFamily: WidgetFamily,
        configuredID: String? = nil
    ) -> WatchWidgetComplicationSnapshot? {
        let snapshots = recommendations()

        if let configuredID,
           let configured = snapshots.first(where: { $0.recommendationID == configuredID }) {
            return configured
        }

        let preferredFamilies = WatchComplicationFamily.preferredFamilies(for: widgetFamily)
        for family in preferredFamilies {
            if let snapshot = snapshots.first(where: { $0.family == family.rawValue }) {
                return snapshot
            }
        }

        return snapshots.first
    }

    static func recommendations() -> [WatchWidgetComplicationSnapshot] {
        let stored = storedComplications()
        return stored.isEmpty ? [.placeholder, .assist] : stored
    }

    private static func storedComplications() -> [WatchWidgetComplicationSnapshot] {
        guard let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID),
              let data = defaults.data(forKey: WatchWidgetConstants.defaultsKey),
              let snapshots = try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: data) else {
            return []
        }

        return snapshots
    }
}
