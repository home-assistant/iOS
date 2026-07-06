import GRDB
import Shared
import SwiftUI

private class LocationHistoryListViewModel: ObservableObject {
    @Published var locationHistoryEntries: [LocationHistoryEntry] = []

    private var token: AnyDatabaseCancellable?

    let dateFormatter = with(DateFormatter()) {
        $0.dateStyle = .short
        $0.timeStyle = .medium
    }

    let title: String = L10n.Settings.LocationHistory.title

    let emptyHistoryTitle: String = L10n.Settings.LocationHistory.empty

    let clearButtonTitle: String = L10n.ClientEvents.View.clear

    init() {
        setupObserver()
    }

    deinit {
        token?.cancel()
    }

    func clear() {
        LocationHistoryEntry.deleteAll()
    }

    private func setupObserver() {
        let observation = ValueObservation.tracking { db in
            try LocationHistoryEntry
                .order(Column(DatabaseTables.LocationHistory.createdAt.rawValue).desc)
                .fetchAll(db)
        }
        token = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("couldn't observe location history: \(error)")
            },
            onChange: { [weak self] entries in
                self?.locationHistoryEntries = entries
            }
        )
    }
}

struct LocationHistoryListView: View {
    @StateObject private var viewModel = LocationHistoryListViewModel()

    var body: some View {
        Form {
            Section {
                if viewModel.locationHistoryEntries.isEmpty {
                    Text(viewModel.emptyHistoryTitle)
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(viewModel.locationHistoryEntries) { entry in
                            LocationHistoryEntryListItemView(
                                entry: entry,
                                dateFormatter: viewModel.dateFormatter
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.locationHistoryEntries.isEmpty == false {
                    Button(viewModel.clearButtonTitle, action: viewModel.clear)
                }
            }
        }
    }
}

final class LocationHistoryListViewHostingController: UIHostingController<LocationHistoryListView> {}

private struct PreviewLocationHistoryListView: View {
    private var locationHistory: [LocationHistoryEntry]

    private func writeToDatabase(_ locationHistory: [LocationHistoryEntry]) {
        LocationHistoryEntry.deleteAll()
        for entry in locationHistory {
            entry.save()
        }
    }

    init(
        locationHistory: [LocationHistoryEntry]
    ) {
        self.locationHistory = locationHistory
        writeToDatabase(locationHistory)
    }

    var body: some View {
        LocationHistoryListView()
            .onAppear {
                writeToDatabase(locationHistory)
            }
    }
}

struct LocationHistoryListView_Previews: PreviewProvider {
    static var previews: some View {
        configuration.previews()
    }

    static var configuration: SnapshottablePreviewConfigurations<[LocationHistoryEntry]> = {
        // swiftlint:disable prohibit_environment_assignment
        Current.date = { Date(timeIntervalSince1970: 1_740_766_173) }
        return .init(
            configurations: [
                .init(item: [], name: "LocationHistoryListView wo/ Locations"),
                .init(
                    item: [
                        LocationHistoryEntry(
                            updateType: .Manual,
                            location: .init(latitude: 41.1234, longitude: 52.2),
                            zone: .defaultSettingValue,
                            accuracyAuthorization: .fullAccuracy,
                            payload: "payload"
                        ),
                        LocationHistoryEntry(
                            updateType: .Periodic,
                            location: nil,
                            zone: nil,
                            accuracyAuthorization: .reducedAccuracy,
                            payload: "payload"
                        ),
                    ],
                    name: "LocationHistoryListView w/ Locations"
                ),
            ],
            configure: { configuration in
                NavigationView {
                    PreviewLocationHistoryListView(
                        locationHistory: configuration
                    )
                }
            }
        )
        // swiftlint:enable prohibit_environment_assignment
    }()
}
