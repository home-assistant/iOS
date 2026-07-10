import Foundation
import PromiseKit
import Shared

/// Observable view model backing the legacy `ComplicationListView`. Reads complications from GRDB
/// and refreshes whenever one is created/edited/deleted.
final class ComplicationListViewModel: ObservableObject {
    @Published private(set) var complicationsByGroup: [ComplicationGroup: [WatchComplication]] = [:]
    @Published private(set) var watchState: HAWatchConnectivity.WatchState = Communicator.shared.currentWatchState
    @Published var isUpdatingComplications = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var watchStateToken: HAWatchConnectivity.ObservationToken?
    private var updateNotificationToken: NSObjectProtocol?
    private var didChangeToken: NSObjectProtocol?

    init() {
        reload()
        observeWatchState()
        observeComplicationsUpdate()
        didChangeToken = NotificationCenter.default.addObserver(
            forName: WatchComplication.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let watchStateToken {
            Communicator.shared.watchState.unobserve(watchStateToken)
        }
        if let updateNotificationToken {
            NotificationCenter.default.removeObserver(updateNotificationToken)
        }
        if let didChangeToken {
            NotificationCenter.default.removeObserver(didChangeToken)
        }
    }

    func reload() {
        let complications = (try? WatchComplication.all()) ?? []
        var grouped: [ComplicationGroup: [WatchComplication]] = [:]
        for complication in complications {
            for group in ComplicationGroup.allCases where group.members.contains(complication.Family) {
                grouped[group, default: []].append(complication)
                break
            }
        }
        complicationsByGroup = grouped
    }

    // MARK: - Capability

    var supportsMultipleComplications: Bool {
        guard let string = Communicator.shared.mostRecentlyReceivedContext.content["watchVersion"] as? String else {
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

    // MARK: - Watch state observation

    private func observeWatchState() {
        watchStateToken = Communicator.shared.watchState.observe { [weak self] state in
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
