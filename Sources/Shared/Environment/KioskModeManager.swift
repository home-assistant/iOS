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

    public init() {
        self.settings = (try? KioskSettings.current()) ?? KioskSettings()
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

    /// The kiosk brightness and volume sensors only make sense on a device acting as a kiosk, so we
    /// keep them enabled only while kiosk mode is enabled. This runs for the observation's initial
    /// value and every subsequent change, and is idempotent so it won't fire spurious updates.
    private func syncKioskSensorsEnabled(with settings: KioskSettings) {
        for sensorId in [WebhookSensorId.kioskBrightness, .kioskVolume] {
            guard Current.sensors.isEnabled(uniqueID: sensorId.rawValue) != settings.enabled else { continue }
            Current.sensors.setEnabled(settings.enabled, forUniqueID: sensorId.rawValue)
        }
    }
}
