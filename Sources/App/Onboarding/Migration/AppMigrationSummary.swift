import Foundation
import Shared

/// What a transfer carried, shown on both ends of the handoff.
struct AppMigrationSummary: Equatable {
    let serverNames: [String]

    var serverCount: Int {
        serverNames.count
    }

    var serversDescription: String {
        serverCount == 1 ? L10n.AppMigration.Complete.serverSingle : L10n.AppMigration.Complete
            .serversTransferred(serverCount)
    }

    static let preview = AppMigrationSummary(serverNames: ["Home", "Cabin"])
}
