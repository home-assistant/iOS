import Combine
import CoreMotion
import Foundation
import PromiseKit
import Shared

/// View model backing `SensorPermissionsView`. Tracks the status of every permission the sensors
/// depend on, and knows how many of them were never presented to the user.
@MainActor
final class SensorPermissionsViewModel: ObservableObject {
    @Published private(set) var statuses: [SensorPermission: SensorPermissionStatus] = [:]
    @Published var alertMessage: String?
    @Published var showAlert = false

    private var motionManager: CMMotionActivityManager?

    /// The permissions this device can actually be asked for, in the order they are displayed.
    var availablePermissions: [SensorPermission] {
        SensorPermission.allCases.filter { permission in
            switch permission {
            case .motion:
                return Current.motion.isActivityAvailable()
            case .focus:
                return Current.focusStatus.isAvailable()
            #if os(iOS) && !targetEnvironment(macCatalyst)
            case .health:
                return Current.healthKitService.isAvailable()
            #endif
            }
        }
    }

    /// How many permissions were never requested, used as the badge of the permissions row.
    var notDeterminedCount: Int {
        availablePermissions.filter { status(for: $0) == .notDetermined }.count
    }

    init() {
        update()
    }

    func status(for permission: SensorPermission) -> SensorPermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    func update() {
        var updatedStatuses: [SensorPermission: SensorPermissionStatus] = [:]
        for permission in availablePermissions {
            updatedStatuses[permission] = systemStatus(for: permission)
        }
        statuses = updatedStatuses
    }

    /// Requests the permission when it was never asked for, otherwise sends the user to the
    /// system settings, which is the only place a decided permission can be changed.
    func handleTap(on permission: SensorPermission) {
        guard status(for: permission) == .notDetermined else {
            openSettings(for: permission)
            return
        }

        switch permission {
        case .motion:
            requestMotionAuthorization()
        case .focus:
            requestFocusAuthorization()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .health:
            requestHealthAuthorization()
        #endif
        }
    }

    // MARK: - Status

    private func systemStatus(for permission: SensorPermission) -> SensorPermissionStatus {
        switch permission {
        case .motion:
            return .init(CMMotionActivityManager.authorizationStatus())
        case .focus:
            return .init(Current.focusStatus.authorizationStatus())
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .health:
            return Current.healthKitService.hasRequestedReadAuthorization() ? .requested : .notDetermined
        #endif
        }
    }

    // MARK: - Requesting

    private func requestMotionAuthorization() {
        guard Current.motion.isActivityAvailable() else { return }
        // Motion has no explicit request API, querying it is what prompts the user.
        let now = Current.date()
        motionManager = CMMotionActivityManager()
        motionManager?.queryActivityStarting(from: now, to: now, to: .main, withHandler: { [weak self] _, _ in
            Task { @MainActor in
                self?.update()
            }
        })
    }

    private func requestFocusAuthorization() {
        guard Current.focusStatus.isAvailable() else { return }
        Current.focusStatus.requestAuthorization().done { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private func requestHealthAuthorization() {
        Task { [weak self] in
            do {
                try await Current.healthKitService.requestReadAuthorization()
            } catch {
                Current.Log.error("Failed to request Apple Health authorization: \(error.localizedDescription)")
                self?.alertMessage = error.localizedDescription
                self?.showAlert = true
            }
            self?.update()
        }
    }
    #endif

    // MARK: - Settings

    private func openSettings(for permission: SensorPermission) {
        let destination: OpenSettingsDestination
        switch permission {
        case .motion:
            destination = .motion
        case .focus:
            destination = .focus
        #if os(iOS) && !targetEnvironment(macCatalyst)
        case .health:
            destination = .health
        #endif
        }
        URLOpener.shared.openSettings(destination: destination, completionHandler: nil)
    }
}
