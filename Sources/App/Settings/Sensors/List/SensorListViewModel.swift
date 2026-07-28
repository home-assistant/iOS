import Foundation
import PromiseKit
import Shared

class SensorListViewModel: ObservableObject {
    /// Every sensor, always sorted alphabetically no matter whether it is enabled or not.
    @Published var sensors: [WebhookSensor] = []
    @Published var lastUpdateDate: Date?
    @Published var periodicUpdateInterval: TimeInterval? = Current.settingsStore.periodicUpdateInterval
    @Published var searchTerm: String = ""
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The sensors matching the current search term, or all of them when not searching.
    var filteredSensors: [WebhookSensor] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return sensors }
        return sensors.filter { $0.Name?.localizedStandardContains(term) ?? false }
    }

    init() {
        Current.sensors.register(observer: self)
    }

    deinit {
        Current.sensors.unregister(observer: self)
    }

    func refresh() {
        firstly {
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .userRequested
            )
        }.catch { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
        }
    }

    func setPeriodicUpdateInterval(_ interval: TimeInterval?) {
        periodicUpdateInterval = interval
        Current.settingsStore.periodicUpdateInterval = interval
    }

    func updateAllSensors(isEnabled: Bool) {
        for sensor in sensors {
            Current.sensors.setEnabled(isEnabled, for: sensor)
        }
    }

    static func sortedAlphabetically(_ sensors: [WebhookSensor]) -> [WebhookSensor] {
        sensors.sorted { lhs, rhs in
            let comparison = (lhs.Name ?? "").localizedStandardCompare(rhs.Name ?? "")
            if comparison == .orderedSame {
                return (lhs.UniqueID ?? "") < (rhs.UniqueID ?? "")
            }
            return comparison == .orderedAscending
        }
    }
}

// MARK: - SensorObserver

extension SensorListViewModel: SensorObserver {
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        refresh()
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        firstly {
            update.sensors
        }.done { [weak self] sensors in
            let sorted = Self.sortedAlphabetically(sensors)
            DispatchQueue.main.async {
                self?.sensors = sorted
                self?.lastUpdateDate = update.on
            }
        }.catch { [weak self] error in
            DispatchQueue.main.async {
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
        }
    }
}
