import UIKit

final class UIApplicationBeaconScanBackgroundExecution: BeaconScanBackgroundExecution {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    func begin(expirationHandler: @escaping () -> Void) {
        guard UIApplication.shared.applicationState != .active,
              identifier == .invalid else { return }

        identifier = UIApplication.shared.beginBackgroundTask(
            withName: "ZoneManagerBeaconScan",
            expirationHandler: { [weak self] in
                expirationHandler()
                self?.end()
            }
        )
    }

    func end() {
        guard identifier != .invalid else { return }

        let identifierToEnd = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(identifierToEnd)
    }
}
