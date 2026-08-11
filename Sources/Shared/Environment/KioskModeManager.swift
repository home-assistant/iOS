import Combine
import Foundation
import GRDB

public enum KioskScreensaverCommand: Equatable {
    case show
    case hide
}

/// Holds the live kiosk mode configuration for the running app.
///
/// The configuration is loaded from GRDB on creation and kept up to date through a
/// `ValueObservation`, so any change persisted by the settings UI is reflected here
/// (and in `Current.kioskSettings`) without manual refreshes.
public final class KioskModeManager: ObservableObject {
    @Published public private(set) var settings: KioskSettings
    @Published public private(set) var isCameraOverlayVisible = false

    public var shouldKeepScreenOn: Bool {
        settings.enabled && settings.keepScreenOn
    }

    /// Emits the current configuration and every subsequent change, for observers outside this module.
    public var settingsPublisher: AnyPublisher<KioskSettings, Never> {
        $settings.eraseToAnyPublisher()
    }

    public var screensaverCommandPublisher: AnyPublisher<KioskScreensaverCommand, Never> {
        screensaverCommandSubject.eraseToAnyPublisher()
    }

    public var cameraOverlayVisiblePublisher: AnyPublisher<Bool, Never> {
        $isCameraOverlayVisible.eraseToAnyPublisher()
    }

    public func requestScreensaver(_ command: KioskScreensaverCommand) {
        screensaverCommandSubject.send(command)
    }

    public func setScreensaverMode(_ mode: KioskScreensaverMode) {
        do {
            try Current.database().write { db in
                var settings = try KioskSettings.fetchOne(db) ?? KioskSettings()
                settings.screensaver.mode = mode
                try settings.insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to set kiosk screensaver mode: \(error)")
        }
    }

    public func setScreensaverDimLevel(_ level: Double) {
        do {
            try Current.database().write { db in
                var settings = try KioskSettings.fetchOne(db) ?? KioskSettings()
                settings.screensaver.dimLevel = min(max(level, 0), 1)
                try settings.insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to set kiosk screensaver dim level: \(error)")
        }
    }

    public func setCameraOverlayVisible(_ visible: Bool) {
        isCameraOverlayVisible = visible
    }

    private let screensaverCommandSubject = PassthroughSubject<KioskScreensaverCommand, Never>()
    private var observation: AnyDatabaseCancellable?
    /// The kiosk `enabled` flag the sensor sync last saw, used to detect actual transitions.
    private var lastSyncedKioskEnabled: Bool

    public init() {
        let settings = (try? KioskSettings.current()) ?? KioskSettings()
        self.settings = settings
        self.lastSyncedKioskEnabled = settings.enabled
        observe()
    }

    private func observe() {
        let observation = ValueObservation.tracking { db in try KioskSettings.fetchOne(db) }
        self.observation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("Kiosk settings observation failed: \(error)")
            },
            onChange: { [weak self] settings in
                // ValueObservation notifies on the main queue by default.
                let settings = settings ?? KioskSettings()
                Current.Log.info("Kiosk settings changed, enabled: \(settings.enabled)")
                self?.settings = settings
                self?.syncKioskSensorsEnabled(with: settings)
            }
        )
    }

    /// Turns the kiosk brightness and volume sensors on or off alongside kiosk mode, but only when
    /// kiosk mode actually transitions. The observation also fires with its initial value on every
    /// manager creation (each app launch, and once per process that touches `Current.kiosk`);
    /// syncing on those deliveries would silently revert a user's explicit choice in
    /// Settings → Sensors, which is how sensors kept deactivating without user input (#5261, #5306).
    private func syncKioskSensorsEnabled(with settings: KioskSettings) {
        guard settings.enabled != lastSyncedKioskEnabled else { return }
        lastSyncedKioskEnabled = settings.enabled

        for sensorId in [WebhookSensorId.kioskBrightness, .kioskVolume] {
            guard Current.sensors.isEnabled(uniqueID: sensorId.rawValue) != settings.enabled else { continue }
            Current.sensors.setEnabled(settings.enabled, forUniqueID: sensorId.rawValue)
        }
    }
}
