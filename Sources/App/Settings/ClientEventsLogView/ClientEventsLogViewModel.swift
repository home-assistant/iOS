import Foundation
import GRDB
import Shared

final class ClientEventsLogViewModel: ObservableObject {
    @Published var events: [ClientEvent] = []
    @Published var searchTerm: String = ""
    @Published var typeFilter: ClientEvent.EventType?

    func loadEvents() {
        events = Current.clientEventStore.getEvents().sorted(by: { $0.date > $1.date })
    }

    func resetTypeFilter() {
        typeFilter = nil
    }
}
