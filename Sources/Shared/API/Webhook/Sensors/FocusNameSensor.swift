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
        focusStatusCancellable = Current.focusStatus.trigger.observe { [weak self] _ in
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
/// name for this sensor to send. `FocusStatusWrapper` clears that name again when the Focus status
/// says every Focus ended, so a name only sticks around while some Focus is running.
///
/// Labs feature, limited to TestFlight builds while it matures, matching the Focus settings screen
/// where the names are created.
final class FocusNameSensor: SensorProvider {
    public enum FocusNameError: Error, Equatable {
        /// No Focus name has been created, so there is nothing this sensor could ever report.
        case unconfigured
        /// Labs feature, limited to TestFlight builds while it matures.
        case unavailable
    }

    /// Reported while iOS says no Focus is running. The stored name is normally already cleared by
    /// then; this also covers the window before that clear lands, and reads taken without one.
    static let notFocusedState = "Not focused"
    /// Reported while a Focus is running that no Focus Filter has named — either the user hasn't
    /// paired that Focus yet, or the Focus status permission is missing so we can't tell.
    static let unknownState = "Unknown"

    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        guard Current.isTestFlight else {
            return .init(error: FocusNameError.unavailable)
        }

        let activeName = Current.focusFilter.activeFocusName()

        guard activeName != nil || !FocusName.all().isEmpty else {
            return .init(error: FocusNameError.unconfigured)
        }

        let isFocused = currentIsFocused()
        let state: String

        if isFocused == false {
            state = Self.notFocusedState
        } else if let activeName, !activeName.isEmpty {
            state = activeName
        } else {
            state = Self.unknownState
        }

        let sensor = with(WebhookSensor(
            name: "Focus name",
            uniqueID: WebhookSensorId.focusName.rawValue,
            icon: "mdi:moon-waning-crescent",
            state: state
        )) {
            if let isFocused {
                $0.Attributes = ["Is focused": isFocused]
            }
        }

        // Set up our observer
        let _: FocusNameSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return .value([sensor])
    }

    /// Whether any Focus is running, when the user granted the Focus status permission. `nil` when
    /// iOS won't tell us, in which case the last name the filter reported is the best we have.
    private func currentIsFocused() -> Bool? {
        guard Current.focusStatus.isAvailable(),
              Current.focusStatus.authorizationStatus() == .authorized else {
            return nil
        }
        return Current.focusStatus.status().isFocused
    }
}
