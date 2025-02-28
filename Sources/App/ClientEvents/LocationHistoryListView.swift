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
	private weak var detailMoveDelegate: LocationHistoryDetailMoveDelegate?
	
	init(
		entry: LocationHistoryEntry,
		dateFormatter: DateFormatter,
		detailMoveDelegate: LocationHistoryDetailMoveDelegate? = nil
	) {
		self.entry = entry
		self.dateFormatter = dateFormatter
		self.detailMoveDelegate = detailMoveDelegate
	}
	
	var body: some View {
		NavigationLink {
			LocationHistoryDetailViewControllerWrapper(
				entry: entry,
				moveDelegate: detailMoveDelegate
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
	private var environment: AppEnvironment
	
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
	
	func clear() {
		let realm = environment.realm()
		environment.realm().reentrantWrite {
			realm.delete(realm.objects(LocationHistoryEntry.self))
		}
	}
	
	init(environment: AppEnvironment) {
		self.environment = environment
		
		setupObserver()
	}
	
	deinit {
		token?.invalidate()
	}
	
	private func setupObserver() {
		let results = environment.realm()
			.objects(LocationHistoryEntry.self)
			.sorted(byKeyPath: "CreatedAt", ascending: false)
		
		token = results.observe { [weak self] changes in
			self?.locationHistoryEntries = results.map(LocationHistoryEntry.init)
		}
	}
}

extension LocationHistoryListViewModel: LocationHistoryDetailMoveDelegate {
	func detail(
		_ controller: LocationHistoryDetailViewController,
		canMove direction: LocationHistoryDetailViewController.MoveDirection
	) -> Bool {
		switch direction {
			case .up:
				locationHistoryEntries.first != controller.entry
			case .down:
				locationHistoryEntries.last != controller.entry
		}
	}
	
	func detail(
		_ controller: LocationHistoryDetailViewController,
		move direction: LocationHistoryDetailViewController.MoveDirection
	) {
		guard
			let currentIndex = locationHistoryEntries.firstIndex(of: controller.entry)
		else { return }
		let newIndex = switch direction {
			case .up: currentIndex - 1
			case .down: currentIndex + 1
		}
		
		guard let newEntry = locationHistoryEntries[safe: newIndex] else { return }
		controller.entry = newEntry
	}
}

struct LocationHistoryListView: View {
	@StateObject private var viewModel: LocationHistoryListViewModel
	
	init(
		environment: AppEnvironment = Current
	) {
		self._viewModel = .init(wrappedValue: .init(environment: environment))
	}
	
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
								dateFormatter: viewModel.dateFormatter,
								detailMoveDelegate: viewModel
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
		LocationHistoryListView(environment: Current)
	}
}

final class LocationHistoryListViewHostingController: UIHostingController<LocationHistoryListView> {
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		[.portrait]
	}
}
