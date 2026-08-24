import Foundation
import Shared
import UIKit

/// Applies a payload handed over by the app being replaced.
///
/// Order matters: the servers go in first because `AppConfigurationTransfer` drops anything pointing
/// at a server this install does not know about. Importing the configuration first would silently
/// throw away every widget, complication and CarPlay item in the payload.
enum AppMigrationImporter {
    static func importServers(from payload: AppMigrationPayload) -> Int {
        Current.servers.restoreState(payload.servers)
        let count = Current.servers.all.count
        Current.Log.info("App migration restored \(count) server(s)")
        return count
    }

    static func importConfiguration(from payload: AppMigrationPayload) async -> (count: Int, failed: Bool) {
        guard let configuration = payload.configuration else {
            Current.Log.info("App migration payload carried no configuration")
            return (0, false)
        }
        do {
            let counts = try await AppConfigurationTransfer.importData(configuration)
            return (counts.values.reduce(0, +), false)
        } catch {
            // The servers are already in. Losing the configuration is worth reporting but not worth
            // unwinding a migration the user cannot easily retry.
            Current.Log.error("App migration failed to import configuration: \(error.localizedDescription)")
            return (0, true)
        }
    }

    /// Records that this install came from the app being replaced, and tells that app so it can
    /// retire itself instead of continuing to talk to Home Assistant alongside this one.
    @MainActor
    static func finish(summary: AppMigrationImportSummary) {
        AppMigrationStatus.importedAt = Current.date()
        guard let url = AppMigrationLink.completionURL(importedServerCount: summary.serverCount) else { return }
        UIApplication.shared.open(url, options: [:]) { opened in
            Current.Log.info("App migration acknowledgement to the previous app opened: \(opened)")
        }
    }
}
