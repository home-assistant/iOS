import UIKit

final class UIApplicationBeaconScanBackgroundExecution: BeaconScanBackgroundExecution {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    private let beginTask: (@escaping () -> Void) -> UIBackgroundTaskIdentifier
    private let endTask: (UIBackgroundTaskIdentifier) -> Void

    init(
        beginTask: @escaping (@escaping () -> Void) -> UIBackgroundTaskIdentifier = { expiration in
            UIApplication.shared.beginBackgroundTask(withName: "ZoneManagerBeaconScan", expirationHandler: expiration)
        },
        endTask: @escaping (UIBackgroundTaskIdentifier) -> Void = { UIApplication.shared.endBackgroundTask($0) }
    ) {
        self.beginTask = beginTask
        self.endTask = endTask
    }

    func begin(expirationHandler: @escaping () -> Void) {
        guard identifier == .invalid else { return }

        identifier = beginTask { [weak self] in
            expirationHandler()
            self?.end()
        }
        if identifier == .invalid {
            expirationHandler()
        }
    }

    func end() {
        guard identifier != .invalid else { return }

        let identifierToEnd = identifier
        identifier = .invalid
        endTask(identifierToEnd)
    }
}
