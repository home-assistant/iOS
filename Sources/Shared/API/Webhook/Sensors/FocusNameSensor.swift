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

        // The Focus Filter tells us which Focus started…
        focusFilterCancellable = Current.focusFilter.state.observe { [weak self] _ in
            self?.signal()
        }
        // …and the Focus status tells us when every Focus ended, which no filter reports.
        focusStatusCancellable = Current.focusStatus.receivedStatus.observe { [weak self] _ in
            self?.signal()
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

/// Reports _which_ Focus is running, which iOS has no API for — empty while none is.
///
/// The user creates the names in the app's Focus settings and pairs each one with a Focus in
/// Settings › Focus › Focus Filters; activating that Focus runs our filter, which stores the paired
/// name for this sensor to send. The stored name is sticky — iOS wipes it on deactivation and
/// skips re-running the filter for quick reactivations — so ending and restarting a Focus blanks
/// and restores the same name. Only knowing every Focus ended blanks it; not being able to tell
/// keeps the last name rather than inventing a state.
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

        let report = FocusReport.current()

        // iOS does tell us when every Focus ends (the pushed status and the filter's reset run),
        // so the name is blanked then; an inconclusive status keeps the last name rather than
        // inventing a state. Empty is also the state before any name exists, which is what keeps
        // the sensor in the list for a user who has yet to configure it.
        let state: String
        if let name = report.name, report.isFocused != false {
            state = name
        } else {
            state = ""
        }

        let sensor = with(WebhookSensor(
            name: "Focus name",
            uniqueID: WebhookSensorId.focusName.rawValue,
            icon: "mdi:moon-waning-crescent",
            state: state
        )) {
            if let isFocused = report.isFocused {
                $0.Attributes = ["Is focused": isFocused]
            }
        }

        // Set up our observer
        let _: FocusNameSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
    }
}
