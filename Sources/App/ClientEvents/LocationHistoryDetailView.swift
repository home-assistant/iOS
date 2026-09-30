#if os(macOS)
import GRDB
import SFSafeSymbols
import Shared
import SwiftUI

/// One location history entry on a map, on the Mac. The toolbar steps through the entries around it,
/// recenters the map, explains what is drawn on it and shares a report of the entry.
struct LocationHistoryDetailView: View {
    @State private var currentEntry: LocationHistoryEntry
    /// Every entry, most recent first: what the up and down buttons step through.
    @State private var entries: [LocationHistoryEntry] = []
    @State private var entriesObservation: AnyDatabaseCancellable?
    @State private var map = LocationHistoryMapView.Coordinator()
    @State private var showHelp = false

    init(currentEntry: LocationHistoryEntry) {
        self._currentEntry = State(initialValue: currentEntry)
    }

    var body: some View {
        LocationHistoryMapView(entry: currentEntry, coordinator: map)
            .navigationTitle(DateFormatter.localizedString(
                from: currentEntry.createdAt,
                dateStyle: .short,
                timeStyle: .medium
            ))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        move(by: -1)
                    } label: {
                        Image(systemSymbol: .arrowUp)
                    }
                    .disabled(!canMove(by: -1))

                    Button {
                        move(by: 1)
                    } label: {
                        Image(systemSymbol: .arrowDown)
                    }
                    .disabled(!canMove(by: 1))

                    Button {
                        map.center(animated: true)
                    } label: {
                        Image(systemSymbol: .scope)
                    }

                    Button {
                        showHelp = true
                    } label: {
                        Image(systemSymbol: .questionmarkCircle)
                    }
                    .help(L10n.helpLabel)

                    Button {
                        map.share(report: currentEntry.debugReport())
                    } label: {
                        Image(systemSymbol: .squareAndArrowUp)
                    }
                }
            }
            .alert(L10n.helpLabel, isPresented: $showHelp) {
                Button(L10n.okLabel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.LocationHistory.Detail.explanation)
            }
            .onAppear(perform: observeEntries)
            .onDisappear {
                entriesObservation?.cancel()
                entriesObservation = nil
            }
    }

    private func observeEntries() {
        guard entriesObservation == nil else { return }

        let observation = ValueObservation.tracking { db in
            try LocationHistoryEntry
                .order(Column(DatabaseTables.LocationHistory.createdAt.rawValue).desc)
                .fetchAll(db)
        }

        entriesObservation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("couldn't observe location history: \(error)")
            },
            onChange: { entries in
                self.entries = entries
            }
        )
    }

    private func index(movingBy offset: Int) -> Int? {
        guard let currentIndex = entries.firstIndex(where: { $0.id == currentEntry.id }) else { return nil }
        let index = currentIndex + offset
        return entries.indices.contains(index) ? index : nil
    }

    private func canMove(by offset: Int) -> Bool {
        index(movingBy: offset) != nil
    }

    private func move(by offset: Int) {
        guard let index = index(movingBy: offset) else { return }
        currentEntry = entries[index]
    }
}

#Preview {
    NavigationView {
        LocationHistoryDetailView(
            currentEntry: LocationHistoryEntry(
                updateType: .Manual,
                location: .init(latitude: 41.1234, longitude: 52.2),
                zone: nil,
                accuracyAuthorization: .fullAccuracy,
                payload: "payload"
            )
        )
    }
}
#endif
