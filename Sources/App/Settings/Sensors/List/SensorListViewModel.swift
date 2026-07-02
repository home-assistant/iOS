import Combine
import CoreMotion
import Foundation
import HAKit
import PromiseKit
import Shared

class SensorListViewModel: ObservableObject {
    enum HealthKitStatus {
        case unavailable
        case notRequested
        case requested
    }

    @Published var sensors: [WebhookSensor] = []
    @Published var lastUpdateDate: Date?
    @Published var motionAuthorizationStatus: CMAuthorizationStatus?
    @Published var focusAuthorizationStatus: FocusStatusWrapper.AuthorizationStatus?
    @Published var healthKitStatus: HealthKitStatus?
    @Published var healthSensorsEnabled: Bool = Current.settingsStore.healthSensorsEnabled
    @Published var periodicUpdateInterval: TimeInterval? = Current.settingsStore.periodicUpdateInterval
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    private var refreshCancellable: AnyCancellable?
    private var motionManager: CMMotionActivityManager?
    private var cancellables = Set<AnyCancellable>()

    var visibleSensors: [WebhookSensor] {
        sensors.filter { sensor in
            healthSensorsEnabled || !HealthKitSensor.isHealthSensor(uniqueID: sensor.UniqueID)
        }
    }

    init() {
        Current.sensors.register(observer: self)
        updatePermissions()
    }

    deinit {
        Current.sensors.unregister(observer: self)
    }

    func updatePermissions() {
        healthSensorsEnabled = Current.settingsStore.healthSensorsEnabled
        healthKitStatus = Current.healthKit.isAvailable() ? healthStatusForCurrentSettings() : .unavailable

        if Current.motion.isActivityAvailable() {
            motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        } else {
            motionAuthorizationStatus = nil
        }

        if Current.focusStatus.isAvailable() {
            focusAuthorizationStatus = Current.focusStatus.authorizationStatus()
        } else {
            focusAuthorizationStatus = nil
        }
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

    func setHealthSensorsEnabled(_ enabled: Bool) -> Promise<Void> {
        if enabled {
            return Current.healthKit.requestReadAuthorization().get { [weak self] in
                Current.settingsStore.healthSensorsEnabled = true
                self?.healthSensorsEnabled = true
                self?.healthKitStatus = .requested
            }
        } else {
            Current.settingsStore.healthSensorsEnabled = false
            healthSensorsEnabled = false
            healthKitStatus = healthStatusForCurrentSettings()
            return .value(())
        }
    }

    // MARK: - Permissions Handling

    func requestMotionAuthorization(completion: @escaping () -> Void) {
        guard Current.motion.isActivityAvailable() else {
            completion()
            return
        }
        let now = Current.date()
        motionManager = CMMotionActivityManager()
        motionManager?.queryActivityStarting(from: now, to: now, to: .main, withHandler: { [weak self] _, _ in
            self?.motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
            completion()
        })
    }

    func openMotionSettings() {
        URLOpener.shared.openSettings(destination: .motion, completionHandler: nil)
    }

    func requestFocusAuthorization(completion: @escaping () -> Void) {
        guard Current.focusStatus.isAvailable() else {
            completion()
            return
        }
        Current.focusStatus.requestAuthorization().done { [weak self] _ in
            self?.focusAuthorizationStatus = Current.focusStatus.authorizationStatus()
            completion()
        }.catch { _ in
            completion()
        }
    }

    func openFocusSettings() {
        URLOpener.shared.openSettings(destination: .focus, completionHandler: nil)
    }

    func updateAllSensors(isEnabled: Bool) {
        for sensor in visibleSensors {
            Current.sensors.setEnabled(isEnabled, for: sensor)
        }
    }

    private func healthStatusForCurrentSettings() -> HealthKitStatus {
        Current.settingsStore.healthSensorsEnabled ? .requested : .notRequested
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
            DispatchQueue.main.async {
                self?.sensors = sensors
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
