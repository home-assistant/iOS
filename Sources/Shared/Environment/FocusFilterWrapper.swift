import Foundation
import HAKit

/// The bridge between the iOS Focus Filter, the only way iOS lets an app learn _which_ Focus is
/// on, and the `focus_name` sensor.
///
/// The name comes from two things the filter says, both stored in the app group so every process
/// reports the same one, and the newest of the two is the name:
/// - Each time iOS performs the filter. It does so with the paired name when that Focus turns on,
///   and with no name once "the previously delivered values are no longer relevant" (WWDC22, Meet
///   Focus filters), which is how a Focus ending reaches the filter.
/// - Each time the app asks iOS for the filter's current values, `SetFocusFilterIntent.current`.
///   That corrects a run that never landed, such as the one for a Focus that ended while iOS
///   didn't launch the app. Only the app can ask, because the filter is declared there.
public class FocusFilterWrapper {
    /// How long a reported name is protected from a run with no name that follows it.
    ///
    /// Switching Focus can perform the filter twice around the same moment, in no guaranteed
    /// order: once with the starting Focus' name and once with none for the Focus that ended.
    /// Without this, the run with no name landing second erases the name the switch just reported.
    /// The app's next reading of the current values corrects the rare Focus that really did end
    /// this quickly.
    static let resetGracePeriod: TimeInterval = 10

    /// How long to wait for iOS to answer with the filter's current values before reporting
    /// without them. A sensor read must not hang on a system call that never returns.
    static var currentValuesTimeout: TimeInterval = 5

    /// Every time iOS performed the filter. Observed by the Focus sensors, because a run is a
    /// Focus change.
    private(set) lazy var runs = UserDefaultsValueSync<FocusFilterState>(settingsKey: "FocusFilterStateKey")

    /// The app's last reading of the filter's current values. Not observed: every sensor read
    /// writes it, so observing it would make each read start the next one.
    private(set) lazy var readings = UserDefaultsValueSync<FocusFilterState>(settingsKey: "FocusFilterReadingKey")

    /// How the app asks iOS for the name the filter currently has, `nil` when no Focus with a name
    /// picked is on.
    public typealias CurrentValuesReader = () async throws -> String?

    /// The app's reader. Unset in every other process.
    private let currentValuesReader = HAProtected<CurrentValuesReader?>(value: nil)

    /// Called by the app at launch with how to ask iOS for the filter's current values.
    public func setCurrentValuesReader(_ reader: @escaping CurrentValuesReader) {
        currentValuesReader.mutate { $0 = reader }
    }

    /// Asks iOS for the filter's current values and stores the answer, when this process can ask
    /// and iOS answers in time.
    func readFromIOS() async {
        guard let reader = currentValuesReader.read({ $0 }) else { return }

        switch await Self.withTimeout(Self.currentValuesTimeout, reader) {
        case let .some(.success(name)):
            readings.value = FocusFilterState(name: name, date: Current.date())
        case let .some(.failure(error)):
            Current.Log.error("focus filter current values unavailable: \(error)")
        case .none:
            Current.Log.error("focus filter current values took over \(Self.currentValuesTimeout)s, skipped")
        }
    }

    /// The newest of what the filter's runs and the app's readings of it said.
    public lazy var activeFocusState: () -> FocusFilterState? = { [weak self] in
        guard let self else { return nil }
        guard let run = runs.value else { return readings.value }
        guard let reading = readings.value else { return run }
        return reading.date >= run.date ? reading : run
    }

    /// The name of the Focus that is on, if the filter said one.
    public lazy var activeFocusName: () -> String? = { [weak self] in
        self?.activeFocusState()?.name
    }

    /// Called by the Focus Filter's App Intent each time iOS performs it: with the paired name when
    /// a Focus turns on, and with `nil` when one ends.
    public lazy var setActiveFocusName: (String?) -> Void = { [weak self] name in
        guard let self else { return }
        let now = Current.date()
        let name = name?.isEmpty == false ? name : nil

        if name == nil, let previous = runs.value, let previousName = previous.name,
           now.timeIntervalSince(previous.date) < Self.resetGracePeriod {
            Current.Log.info("focus filter ignoring run with no name right after \(previousName) was reported")
            return
        }

        runs.value = FocusFilterState(name: name, date: now)
    }

    /// Stops reporting a name the user deleted in settings. A filter still paired with it reports
    /// it again the next time it runs, which is when the name exists again as far as the app is
    /// concerned.
    public lazy var forgetFocusName: (String) -> Void = { [weak self] name in
        guard let self else { return }
        let now = Current.date()
        if runs.value?.name == name {
            runs.value = FocusFilterState(name: nil, date: now)
        }
        if readings.value?.name == name {
            readings.value = FocusFilterState(name: nil, date: now)
        }
    }

    /// Runs `operation`, giving up on it after `timeout` without waiting for it to finish, which a
    /// task group would do even once cancelled.
    private static func withTimeout<T>(
        _ timeout: TimeInterval,
        _ operation: @escaping () async throws -> T
    ) async -> Result<T, Error>? {
        await withCheckedContinuation { continuation in
            let resumed = HAProtected<Bool>(value: false)
            let resume: (Result<T, Error>?) -> Void = { result in
                let isFirst = resumed.mutate { resumed -> Bool in
                    defer { resumed = true }
                    return !resumed
                }
                if isFirst {
                    continuation.resume(returning: result)
                }
            }
            let timer = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                resume(nil)
            }
            Task {
                do {
                    let value = try await operation()
                    resume(.success(value))
                } catch {
                    resume(.failure(error))
                }
                timer.cancel()
            }
        }
    }
}
