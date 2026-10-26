import Foundation
import HAKit
import PromiseKit

final class FocusNameSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var focusFilterCancellable: HACancellable?
    private var focusStatusCancellable: HACancellable?
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .focusName,
        ])
    }

    deinit {
        focusFilterCancellable?.cancel()
        focusStatusCancellable?.cancel()
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }

        // A filter run changes the name.
        focusFilterCancellable = Current.focusFilter.runs.observe { [weak self] _ in
            self?.signal()
        }
        // A status push changes the "Is focused" attribute. The Intents extension that received
        // it reports it itself, so this only keeps the sensor on screen current: in the background
        // it would add a full update of every sensor to that extension's short run.
        focusStatusCancellable = Current.focusStatus.pushes.observe { [weak self] _ in
            #if os(watchOS)
            self?.signal()
            #else
            if Current.isForegroundApp() {
                self?.signal()
            }
            #endif
        }
        isObserving = true

        #if DEBUG
        notifyObservation?()
        #endif
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        focusFilterCancellable?.cancel()
        focusStatusCancellable?.cancel()
        isObserving = false
    }
}

/// Reports _which_ Focus is on, which iOS has no API for. Empty while none is.
///
/// The user creates the names in the app's Focus settings and pairs each one with a Focus in
/// Settings › Focus › Focus Filters. iOS performs the filter with that name when the Focus turns
/// on and with none when it ends, and the app also asks iOS for the filter's current values on
/// every read, see `FocusReport`.
///
/// The sensor is always listed, never erroring out while nothing is configured: its detail screen
/// is the only route to the Focus names, so a sensor that dropped out of the list until a name
/// existed left a new user with no way to create their first one.
///
/// Labs feature, limited to TestFlight builds while it matures, matching the Focus settings screen
/// where the names are created.
final class FocusNameSensor: SensorProvider {
    public enum FocusNameError: Error, Equatable {
        /// Labs feature, limited to TestFlight builds while it matures.
        case unavailable
    }

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard Current.isTestFlight else {
            return .init(error: FocusNameError.unavailable)
        }

        return FocusReport.current().map { [self] report in
            let _: FocusNameSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

            // Empty while no named Focus is on, which is also the state before any name exists,
            // what keeps the sensor in the list for a user who has yet to configure it.
            return [with(WebhookSensor(
                name: "Focus name",
                uniqueID: WebhookSensorId.focusName.rawValue,
                icon: "mdi:moon-waning-crescent",
                state: report.name ?? ""
            )) {
                if let isFocused = report.isFocused {
                    $0.Attributes = ["Is focused": isFocused]
                }
            }]
        }
    }
}
