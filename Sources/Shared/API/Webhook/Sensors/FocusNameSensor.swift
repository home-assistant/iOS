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

/// Reports _which_ Focus is running, which iOS has no API for.
///
/// The user creates the names in the app's Focus settings and pairs each one with a Focus in
/// Settings › Focus › Focus Filters; activating that Focus runs our filter, which stores the paired
/// name for this sensor to send. `FocusReport` pairs that name with the Focus status iOS pushes us
/// to work out whether it is still the Focus that is running.
final class FocusNameSensor: SensorProvider {
    public enum FocusNameError: Error, Equatable {
        /// No Focus name has been created, so there is nothing this sensor could ever report.
        case unconfigured
    }

    /// Reported once iOS has told us every Focus ended, and while nothing has ever told us one is
    /// running.
    static let notFocusedState = "Not focused"
    /// Reported while a Focus is running that no Focus Filter has named — either the user hasn't
    /// paired that Focus yet, or the Focus status permission is missing so we can't tell.
    static let unknownState = "Unknown"

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        let report = FocusReport.current()

        guard report.name != nil || !FocusName.all().isEmpty else {
            return .init(error: FocusNameError.unconfigured)
        }

        let state: String

        if let name = report.name {
            state = name
        } else if report.isFocused == false {
            state = Self.notFocusedState
        } else {
            state = Self.unknownState
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
