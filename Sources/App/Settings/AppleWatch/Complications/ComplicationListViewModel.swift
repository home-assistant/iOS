import Communicator
import Foundation
import PromiseKit
import RealmSwift
import Shared
import Version

/// Observable view model backing `ComplicationListView`. Wraps the Realm
/// notification tokens used to drive the existing Eureka controller.
final class ComplicationListViewModel: ObservableObject {
    @Published private(set) var complicationsByGroup: [ComplicationGroup: [WatchComplication]] = [:]
    @Published private(set) var watchState: WatchState = Communicator.shared.currentWatchState
    @Published var isUpdatingComplications = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var realmToken: NotificationToken?
    private var watchStateToken: Any?
    private var updateNotificationToken: NSObjectProtocol?

    init() {
        observeRealm()
        observeWatchState()
        observeComplicationsUpdate()
    }

    deinit {
        realmToken?.invalidate()
        if let watchStateToken {
            WatchState.unobserve(watchStateToken)
        }
        if let updateNotificationToken {
            NotificationCenter.default.removeObserver(updateNotificationToken)
        }
    }

    // MARK: - Capability

    var supportsMultipleComplications: Bool {
        guard let string = Communicator.shared.mostRecentlyReceievedContext.content["watchVersion"] as? String else {
            return false
        }
        do {
            let version = try Version(string)
            return version >= Version(major: 7)
        } catch {
            Current.Log.error("failed to parse \(string), saying we're not 7+")
            return false
        }
    }

    var currentFamilies: Set<ComplicationGroupMember> {
        Set(complicationsByGroup.values.flatMap { $0 }.map(\.Family))
    }

    // MARK: - Manual update

    func updateComplications() {
        isUpdatingComplications = true
        Current.notificationManager.commandManager.updateComplications()
            .ensure { [weak self] in
                DispatchQueue.main.async {
                    self?.isUpdatingComplications = false
                }
            }
            .catch { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
    }

    // MARK: - Realm observation

    private func observeRealm() {
        let results = Current.realm().objects(WatchComplication.self).sorted(byKeyPath: "rawFamily")
        realmToken = results.observe { [weak self] _ in
            self?.rebuildGroups(from: results)
        }
    }

    private func rebuildGroups(from results: Results<WatchComplication>) {
        var grouped: [ComplicationGroup: [WatchComplication]] = [:]
        for complication in results {
            for group in ComplicationGroup.allCases where group.members.contains(complication.Family) {
                grouped[group, default: []].append(complication)
                break
            }
        }
        complicationsByGroup = grouped
    }

    // MARK: - Watch state observation

    private func observeWatchState() {
        watchStateToken = WatchState.observe { [weak self] state in
            DispatchQueue.main.async {
                self?.watchState = state
            }
        }
    }

    private func observeComplicationsUpdate() {
        updateNotificationToken = NotificationCenter.default.addObserver(
            forName: NotificationCommandManager.didUpdateComplicationsNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.watchState = Communicator.shared.currentWatchState
        }
    }
}

extension ComplicationListViewModel {
    var remainingUpdatesDescription: String {
        switch watchState {
        case .notPaired:
            return L10n.Watch.Configurator.List.ManualUpdates.State.notPaired
        case .paired(.notInstalled):
            return L10n.Watch.Configurator.List.ManualUpdates.State.notInstalled
        case .paired(.installed(.notEnabled, _)):
            return L10n.Watch.Configurator.List.ManualUpdates.State.notEnabled
        case let .paired(.installed(.enabled(numberOfUpdatesAvailableToday: remaining), _)):
            return NumberFormatter.localizedString(from: NSNumber(value: remaining), number: .none)
        }
    }
}
