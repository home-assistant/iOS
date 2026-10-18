import Foundation
import Shared

/// Backs the Siri settings screen: one switch per server, saved as it changes.
@MainActor
final class SiriSettingsViewModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: String
        let name: String
        var isExposed: Bool
    }

    @Published var rows: [Row] = []

    func load() {
        let hidden = SiriServerExposure.hiddenServerIds()
        rows = Current.servers.all
            .sorted { $0.info.name.localizedCaseInsensitiveCompare($1.info.name) == .orderedAscending }
            .map { server in
                Row(
                    id: server.identifier.rawValue,
                    name: server.info.name,
                    isExposed: !hidden.contains(server.identifier.rawValue)
                )
            }
    }

    /// Saves the choice and rebuilds what the system holds, so the change shows up without
    /// waiting for the next database update or app launch.
    func setExposed(_ isExposed: Bool, serverId: String) {
        SiriServerExposure.setExposed(isExposed, serverId: serverId)
        if let index = rows.firstIndex(where: { $0.id == serverId }) {
            rows[index].isExposed = isExposed
        }
        NotificationCenter.default.post(name: .siriEntityExposureDidChange, object: nil)
    }
}

public extension Notification.Name {
    /// Posted when a server's Siri exposure changes, so the Spotlight index and the App Shortcut
    /// parameters can be rebuilt rather than waiting for the next database update.
    static let siriEntityExposureDidChange = Notification.Name("siriEntityExposureDidChange")
}
