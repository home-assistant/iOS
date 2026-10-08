import Foundation
import HAKit
import PromiseKit

/// Retries a sensor update that failed to reach its server, until one does.
///
/// Home Assistant only ever knows what the last update to arrive carried, so a failed one leaves
/// the entities on the value before it until whatever update happens next — which, for a change
/// reported from a background launch, can be hours away. One retry per server stays pending; an
/// update that gets through in the meantime makes it redundant and cancels it. A retry reads the
/// sensors afresh rather than resending what failed, so it never carries a value older than one a
/// newer run already delivered.
final class SensorUpdateRetry {
    /// How long each attempt waits after the failure before it; the last one repeats until an
    /// update succeeds. The first is short enough to land inside the background time an app that
    /// was launched to report a change still has.
    static let delays: [TimeInterval] = [15, 60, 120, 300, 900]

    private struct State {
        /// The providers the pending retry has to read, or `nil` for all of them — a full update
        /// absorbs any limited one.
        var providers: [SensorProvider.Type]?
        /// Identifies the scheduled run, so a success in the meantime can disown it.
        var pendingToken: UUID?
        /// How many retries have been scheduled since the last success.
        var attempt = 0
    }

    private let state = HAProtected<State>(value: State())
    private let perform: ([SensorProvider.Type]?) -> Promise<Void>

    /// Runs the block after the delay. Replaceable in tests, which can't wait minutes.
    var schedule: (TimeInterval, @escaping () -> Void) -> Void = { delay, block in
        after(seconds: delay).done { _ in block() }
    }

    /// - Parameter perform: sends an update limited to the given providers, or everything for
    ///   `nil`, reporting back through `noteSuccess()` and `noteFailure(limitedTo:)` like any run.
    init(perform: @escaping ([SensorProvider.Type]?) -> Promise<Void>) {
        self.perform = perform
    }

    /// An update reached the server: whatever a pending retry would have sent is superseded.
    func noteSuccess() {
        let cancelled: Bool = state.mutate { state in
            defer { state = State() }
            return state.pendingToken != nil
        }
        if cancelled {
            Current.Log.info("sensor update retry no longer needed, a newer update got through")
        }
    }

    /// An update didn't reach the server: retry, unless one is already on its way.
    func noteFailure(limitedTo providers: [SensorProvider.Type]?) {
        guard !Current.isAppExtension else {
            // Nothing outlives the intent an extension was launched for; the app's next update
            // reads the same stored state and carries the change.
            return
        }

        let scheduled: (token: UUID, delay: TimeInterval)? = state.mutate { state in
            if state.pendingToken != nil {
                state.providers = Self.merge(state.providers, with: providers)
                return nil
            }
            let token = UUID()
            state.providers = providers
            state.pendingToken = token
            let delay = Self.delays[min(state.attempt, Self.delays.count - 1)]
            state.attempt += 1
            return (token, delay)
        }

        guard let scheduled else { return }
        Current.Log.info("retrying the sensor update in \(scheduled.delay)s")
        schedule(scheduled.delay) { [weak self] in
            self?.fire(scheduled.token)
        }
    }

    private func fire(_ token: UUID) {
        let providers: [SensorProvider.Type]?? = state.mutate { state in
            guard state.pendingToken == token else { return nil }
            state.pendingToken = nil
            return .some(state.providers)
        }
        // A success since it was scheduled cancelled it.
        guard let providers else { return }
        perform(providers).cauterize()
    }

    private static func merge(
        _ existing: [SensorProvider.Type]?,
        with new: [SensorProvider.Type]?
    ) -> [SensorProvider.Type]? {
        guard let existing, let new else { return nil }
        var merged = existing
        for provider in new where !merged.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(provider) }) {
            merged.append(provider)
        }
        return merged
    }
}
