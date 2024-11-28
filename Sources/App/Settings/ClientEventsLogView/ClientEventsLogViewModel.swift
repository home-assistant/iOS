import Foundation
import GRDB
import Shared

final class ClientEventsLogViewModel: ObservableObject {
    @Published var events: [ClientEvent] = []
    @Published var searchTerm: String = ""
    @Published var typeFilter: ClientEvent.EventType?

    private var eventsObservation: AnyDatabaseCancellable?

    deinit {
        eventsObservation?.cancel()
    }

    @MainActor
    func subscribeEvents() {
        observeChanges()
    }

    func resetTypeFilter() {
        typeFilter = nil
    }

    @MainActor
    private func observeChanges() {
        eventsObservation?.cancel()
        let observation = ValueObservation.tracking(ClientEvent.fetchAll)
        eventsObservation = observation.start(
            in: Current.database,
            onError: { error in
                Current.Log.error("Client events observation failed with error: \(error)")
            },
            onChange: { @MainActor [weak self] _ in
                // Observation uses main queue https://swiftpackageindex.com/groue/grdb.swift/v6.29.3/documentation/grdb/valueobservation#ValueObservation-Scheduling
                self?.events = Current.clientEventStore.getEvents()
            }
        )
    }
}
