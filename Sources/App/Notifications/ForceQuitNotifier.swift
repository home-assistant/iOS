import CoreLocation
import Foundation
import Shared
import UIKit

/// Warns the user, with a local notification, that closing the app from the app switcher stops its
/// background features — location updates, sensors, local push — until the app is opened again.
///
/// iOS posts `willTerminateNotification` when the app is killed while it is still running in the
/// background, which is exactly the moment worth explaining. The warning can be turned off in
/// Settings › Notifications.
final class ForceQuitNotifier {
    /// Termination only leaves the app a few seconds, so we wait — briefly — for the notification
    /// center to take the request before the process goes away.
    private static let deliveryTimeout: TimeInterval = 2

    /// `CLLocationManager`'s status is not part of `Current`, so it is injected to keep this testable.
    private let locationPermissionStatus: () -> CLAuthorizationStatus

    init(
        notificationCenter: NotificationCenter = .default,
        locationPermissionStatus: @escaping () -> CLAuthorizationStatus = { Current.location.permissionStatus }
    ) {
        self.locationPermissionStatus = locationPermissionStatus
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func applicationWillTerminate() {
        notifyIfNeeded()
    }

    func notifyIfNeeded() {
        guard shouldNotify else { return }

        Current.Log.info("App is terminating, warning the user about background features stopping")

        // Sending off the caller's thread keeps the completion — and so the signal we are waiting on —
        // from ever landing on the thread that is blocked here.
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            Current.notificationDispatcher.send(
                .init(
                    id: .forceQuit,
                    title: L10n.ForceQuit.Notification.title,
                    body: L10n.ForceQuit.Notification.body
                ),
                completion: { semaphore.signal() }
            )
        }
        _ = semaphore.wait(timeout: .now() + Self.deliveryTimeout)
    }

    /// The warning is only useful when closing the app actually costs the user something, so it is
    /// limited to devices that are signed in and set up to report location in the background.
    private var shouldNotify: Bool {
        // Quitting is an ordinary, deliberate action on the Mac rather than something to warn about.
        guard !Current.isCatalyst else { return false }
        guard Current.settingsStore.notifyOnForceQuit else { return false }
        guard !Current.servers.all.isEmpty else { return false }
        guard locationPermissionStatus() == .authorizedAlways else { return false }
        return Current.settingsStore.locationSources.isAnyEnabled
    }
}
