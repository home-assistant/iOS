import Foundation
import Shared

final class ClientEventsLogViewModel: ObservableObject {
    @Published var events: [ClientEvent] = []
    @Published var searchTerm: String = ""
    @Published var typeFilter: ClientEvent.EventType?

    func fetchEvents() {
        events = Current.clientEventStore.getEvents()
    }

    func resetTypeFilter() {
        typeFilter = nil
    }
}
