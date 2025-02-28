import RealmSwift
import Shared
import SwiftUI

extension LocationHistoryEntry: @retroactive Identifiable {
	public var id: String {
		ObjectIdentifier(self).hashValue.description
	}
}

private struct LocationHistoryEntryListItemView: View {
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
			.edgesIgnoringSafeArea([.top,.bottom])
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

#Preview {
	NavigationView {
		Form {
			Section {
				LocationHistoryEntryListItemView(
					entry: .init(
						updateType: .Manual,
						location: .init(latitude: 41.1234, longitude: 52.2),
						zone: .defaultSettingValue,
						accuracyAuthorization: .fullAccuracy,
						payload: "payload"
					),
					dateFormatter: with(DateFormatter()) {
						$0.dateStyle = .short
						$0.timeStyle = .medium
					}
				)
				LocationHistoryEntryListItemView(
					entry: .init(
						updateType: .Periodic,
						location: nil,
						zone: nil,
						accuracyAuthorization: .reducedAccuracy,
						payload: "payload"
					),
					dateFormatter: with(DateFormatter()) {
						$0.dateStyle = .short
						$0.timeStyle = .medium
					}
				)
			}
		}
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
		
		token = results.observe { [weak self] changes in
			self?.locationHistoryEntries = results.map(LocationHistoryEntry.init)
		}
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

#Preview {
	NavigationView {
		LocationHistoryListView()
	}
}

final class LocationHistoryListViewHostingController: UIHostingController<LocationHistoryListView> {
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		[.portrait]
	}
}
