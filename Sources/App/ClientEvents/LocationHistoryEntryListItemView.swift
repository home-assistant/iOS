import Shared
import SwiftUI

struct LocationHistoryEntryListItemView: View {
    private let entry: LocationHistoryEntry
    private let dateFormatter: DateFormatter

    init(
        entry: LocationHistoryEntry,
        dateFormatter: DateFormatter
    ) {
        self.entry = entry
        self.dateFormatter = dateFormatter
    }

    var body: some View {
        NavigationLink {
            LocationHistoryDetailViewControllerWrapper(
                currentEntry: entry
            )
            .edgesIgnoringSafeArea([.top, .bottom])
        } label: {
            VStack(alignment: .leading) {
                Text(dateFormatter.string(from: entry.CreatedAt))
                    .foregroundStyle(.primary)
                if let trigger = entry.Trigger {
                    Text(trigger)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LocationHistoryEntryListItemView_Previews: PreviewProvider {
    static var previews: some View {
        configuration.previews()
    }

    static var configuration: SnapshottablePreviewConfigurations<LocationHistoryEntry> = .init(
        configurations: [
            .init(
                item: LocationHistoryEntry(
                    updateType: .Manual,
                    location: .init(latitude: 41.1234, longitude: 52.2),
                    zone: .defaultSettingValue,
                    accuracyAuthorization: .fullAccuracy,
                    payload: "payload"
                ),
                name: "LocationHistoryEntryListItemView"
            ),
        ]
    ) { item in
        List {
            Section {
                LocationHistoryEntryListItemView(
                    entry: item,
                    dateFormatter: with(DateFormatter()) {
                        $0.dateStyle = .short
                        $0.timeStyle = .medium
                    }
                )
            }
        }
    }
}
