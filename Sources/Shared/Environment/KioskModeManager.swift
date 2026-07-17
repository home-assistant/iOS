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
    @Published public private(set) var isScreensaverVisible = false

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

    /// Emits the current screensaver visibility and every subsequent change, so the kiosk screensaver
    /// sensor can report whether the screensaver is on screen.
    public var screensaverVisiblePublisher: AnyPublisher<Bool, Never> {
        $isScreensaverVisible.eraseToAnyPublisher()
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

    /// Called by the screensaver controller whenever the screensaver is shown or dismissed.
    public func setScreensaverVisible(_ visible: Bool) {
        isScreensaverVisible = visible
    }

    private let screensaverCommandSubject = PassthroughSubject<KioskScreensaverCommand, Never>()
    private var observation: AnyDatabaseCancellable?
    private var motionWakeCancellable: AnyCancellable?
    private var isObservingMotion = false

    public init() {
        self.settings = (try? KioskSettings.current()) ?? KioskSettings()
        observe()
        observeScreensaverForMotionWake()
    }

    /// While kiosk mode is enabled and the screensaver is visible, observe the camera
    /// motion detector so that motion dismisses the screensaver. Registering starts the
    /// camera capture session; unregistering stops it, so the camera only runs while
    /// the screensaver is on screen.
    private func observeScreensaverForMotionWake() {
        motionWakeCancellable = Publishers.CombineLatest($isScreensaverVisible, $settings)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible, settings in
                self?.updateMotionObservation(
                    shouldObserve: visible && settings.enabled && settings.screensaver.wakeOnCameraMotion
                )
            }
    }

    private func updateMotionObservation(shouldObserve: Bool) {
        guard shouldObserve != isObservingMotion else { return }
        isObservingMotion = shouldObserve
        if shouldObserve {
            Current.motionDetection.register(observer: self)
        } else {
            Current.motionDetection.unregister(observer: self)
        }
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

    /// The kiosk brightness, volume and screensaver sensors only make sense on a device acting as a
    /// kiosk, so we keep them enabled only while kiosk mode is enabled. This runs for the observation's
    /// initial value and every subsequent change, and is idempotent so it won't fire spurious updates.
    private func syncKioskSensorsEnabled(with settings: KioskSettings) {
        for sensorId in [WebhookSensorId.kioskBrightness, .kioskVolume, .kioskScreensaver] {
            guard Current.sensors.isEnabled(uniqueID: sensorId.rawValue) != settings.enabled else { continue }
            Current.sensors.setEnabled(settings.enabled, forUniqueID: sensorId.rawValue)
        }
    }
}

// MARK: - MotionDetectionObserver

extension KioskModeManager: MotionDetectionObserver {
    public func motionStateDidChange(for manager: MotionDetectionManager) {
        guard manager.isMotionDetected else { return }
        Current.Log.info("Kiosk: motion detected while screensaver visible, hiding screensaver")
        requestScreensaver(.hide)
    }
}
