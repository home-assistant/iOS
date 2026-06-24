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
                Current.Log.info("Kiosk settings changed, enabled: \(settings?.enabled ?? false)")
                self?.settings = settings ?? KioskSettings()
            }
        )
    }
}
