import RealmSwift
import Shared
import SwiftUI

extension LocationHistoryEntry: @retroactive Identifiable {
    public var id: String {
        ObjectIdentifier(self).hashValue.description
    }
}

private class LocationHistoryListViewModel: ObservableObject {
    @ObservedResults(LocationHistoryEntry.self) var locationHistoryEntryResults
    @Published var locationHistoryEntries: [LocationHistoryEntry] = []

    private var token: NotificationToken?

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
        token?.invalidate()
    }

    func clear() {
        let realm = Current.realm()
        realm.reentrantWrite {
            realm.delete(realm.objects(LocationHistoryEntry.self))
        }
    }

    private func setupObserver() {
        let results = Current.realm()
            .objects(LocationHistoryEntry.self)
            .sorted(byKeyPath: "CreatedAt", ascending: false)

        token = results.observe { [weak self] _ in
            self?.updateEntries(with: results)
        }
        updateEntries(with: results)
    }

    private func updateEntries(with results: Results<LocationHistoryEntry>) {
        locationHistoryEntries = results.map(LocationHistoryEntry.init)
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

    private func writeToRealm(_ locationHistory: [LocationHistoryEntry]) {
        let realm = Current.realm()
        realm.reentrantWrite {
            realm.deleteAll()
            for entry in locationHistory {
                let newEntry = LocationHistoryEntry(value: entry)
                realm.add(newEntry)
            }
        }
    }

    init(
        locationHistory: [LocationHistoryEntry]
    ) {
        self.locationHistory = locationHistory
        writeToRealm(locationHistory)
    }

    var body: some View {
        LocationHistoryListView()
            .onAppear {
                writeToRealm(locationHistory)
            }
    }
}

struct LocationHistoryListView_Previews: PreviewProvider {
    static var previews: some View {
        configuration.previews()
    }

    static var configuration: SnapshottablePreviewConfigurations<[LocationHistoryEntry]> = {
        Current.date = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd-MM-yyyy 'T'HH:mm:ssZ"
            return dateFormatter.date(from: "01-01-2025 T00:00:00Z")!
        }
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
                // Simulating a typical iPhone screen size (e.g., iPhone 13/14/15)
                .frame(width: 375, height: 812)
            }
        )
    }()
}
