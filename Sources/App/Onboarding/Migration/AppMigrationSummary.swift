import Foundation
import Shared

/// What a transfer carried, shown on both ends of the handoff.
struct AppMigrationSummary: Equatable {
    let serverNames: [String]
    /// What the previous app was allowed to use; empty on the previous app's own screen.
    var grantedPermissions: [SensorPermission] = []

    var serverCount: Int {
        serverNames.count
    }

    var completionBody: String {
        serverCount == 0 ? L10n.AppMigration.Complete.bodyNoServers : L10n.AppMigration.Complete.body
    }

    var serversDescription: String {
        serverCount == 1 ? L10n.AppMigration.Complete.serverSingle : L10n.AppMigration.Complete
            .serversTransferred(serverCount)
    }

    static let preview = AppMigrationSummary(
        serverNames: ["Home", "Cabin"],
        grantedPermissions: [.location, .notification]
    )
}
