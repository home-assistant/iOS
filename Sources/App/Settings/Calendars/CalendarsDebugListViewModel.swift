import Foundation
import Shared

@MainActor
final class CalendarsDebugListViewModel: ObservableObject {
    @Published private(set) var calendars: [HACalendar] = []
    @Published var errorMessage: String?

    private let server: Server

    init(server: Server) {
        self.server = server
    }

    func load() {
        calendars = HACalendar.all(serverId: server.identifier.rawValue)
    }

    /// Re-reads the calendars from Home Assistant and rewrites the stored rows, the same way the
    /// app database update routine does.
    func refresh() async {
        let succeeded = await Current.calendarsModel().refresh(server: server)
        load()
        errorMessage = succeeded ? nil : L10n.Settings.Debugging.Calendars.refreshFailed
    }
}
