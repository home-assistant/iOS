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
///
/// Every update is numbered as its request goes out, so a success only stands down the failures it
/// really supersedes: the ones sent before it, and only for the sensors it carried. An old request
/// resolving after a newer one failed doesn't cancel that newer failure's retry, and a Focus-only
/// update getting through doesn't cancel the retry of a full update that didn't. Sent order rather
/// than start order, because overlapping runs read their sensors in whatever order their slowest
/// provider allows: the run that sends last carries the newest values, whenever it started.
final class SensorUpdateRetry {
    /// How long each attempt waits after the failure before it; the last one repeats until an
    /// update succeeds.
    static let delays: [TimeInterval] = [15, 60, 120, 300, 900]

    /// Waits up to this long are held open by a background task, so the first retry of a change
    /// reported from a background launch lands while the app still runs rather than after iOS
    /// suspends it. Nothing holds the process for the longer waits: a suspended app can't run
    /// anything, so those fire when it next does, where the update every launch and foreground
    /// makes usually gets there first and calls the retry off.
    static let heldAliveUpTo: TimeInterval = 30

    private struct Failed {
        var provider: SensorProvider.Type
        var generation: UInt64
    }

    private struct State {
        var nextGeneration: UInt64 = 1
        /// The newest full update that failed, which a retry of everything covers.
        var fullFailedAt: UInt64?
        /// The limited updates that failed, by provider, each with the newest update that failed it.
        var limitedFailed = [ObjectIdentifier: Failed]()
        /// The newest full update that got through, and the newest limited one per provider. A
        /// failure older than a success that covers it has been overtaken: Home Assistant already
        /// holds a newer value, so that failure is not owed a retry.
        var fullSucceededAt: UInt64 = 0
        var limitedSucceededAt = [ObjectIdentifier: UInt64]()
        /// Identifies the scheduled run, so a success in the meantime can disown it.
        var pendingToken: UUID?
        /// How many retries have been scheduled since the last time nothing was left to retry.
        var attempt = 0

        var hasWork: Bool {
            fullFailedAt != nil || !limitedFailed.isEmpty
        }

        /// What the retry has to read: everything while a full update is owed, else the providers
        /// whose own updates failed.
        var scope: [SensorProvider.Type]? {
            fullFailedAt != nil ? nil : limitedFailed.values.map(\.provider)
        }

        /// Whether a success newer than the update carried everything the update did: a full
        /// success covers any update, a limited one only the providers it read.
        func isCovered(generation: UInt64, limitedTo provider: SensorProvider.Type?) -> Bool {
            if generation < fullSucceededAt {
                return true
            }
            guard let provider else { return false }
            return generation < limitedSucceededAt[ObjectIdentifier(provider), default: 0]
        }
    }

    private let state = HAProtected<State>(value: State())
    private let perform: ([SensorProvider.Type]?) -> Promise<Void>

    /// Runs the block after the delay. Replaceable in tests, which can't wait minutes.
    var schedule: (TimeInterval, @escaping () -> Void) -> Void = { delay, block in
        SensorUpdateRetry.wait(delay, holdingBackgroundTask: delay <= SensorUpdateRetry.heldAliveUpTo, then: block)
    }

    /// - Parameter perform: sends an update limited to the given providers, or everything for
    ///   `nil`, reporting back through `noteSuccess` and `noteFailure` like any run.
    init(perform: @escaping ([SensorProvider.Type]?) -> Promise<Void>) {
        self.perform = perform
    }

    /// Numbers an update whose request is about to go out, so its outcome can be ordered against the
    /// others'.
    func beginUpdate() -> UInt64 {
        state.mutate { state in
            defer { state.nextGeneration += 1 }
            return state.nextGeneration
        }
    }

    /// An update reached the server: the failures it supersedes — older, and for the sensors it
    /// carried — are no longer owed a retry, whether they were noted before this or come in after.
    func noteSuccess(generation: UInt64, limitedTo providers: [SensorProvider.Type]?) {
        let cleared: Bool = state.mutate { state in
            if let providers {
                for provider in providers {
                    let key = ObjectIdentifier(provider)
                    state.limitedSucceededAt[key] = max(state.limitedSucceededAt[key, default: 0], generation)
                }
            } else {
                state.fullSucceededAt = max(state.fullSucceededAt, generation)
            }

            guard state.hasWork else { return false }

            if let providers {
                for provider in providers {
                    let key = ObjectIdentifier(provider)
                    if let failed = state.limitedFailed[key], failed.generation < generation {
                        state.limitedFailed[key] = nil
                    }
                }
            } else {
                if let fullFailedAt = state.fullFailedAt, fullFailedAt < generation {
                    state.fullFailedAt = nil
                }
                state.limitedFailed = state.limitedFailed.filter { $0.value.generation >= generation }
            }

            guard !state.hasWork else { return false }
            state.pendingToken = nil
            state.attempt = 0
            return true
        }
        if cleared {
            Current.Log.info("sensor update retry no longer needed, a newer update got through")
        }
    }

    /// An update didn't reach the server: retry, unless one is already on its way or a newer
    /// update has carried the same sensors since.
    ///
    /// The second case is how an overlapping pair behaves: `WebhookManager` replaces the older
    /// request with the newer one, and when the server answers the newer one before the older
    /// one's cancellation is reported, the failure arrives after the success that overtook it.
    func noteFailure(generation: UInt64, limitedTo providers: [SensorProvider.Type]?) {
        guard !Current.isAppExtension else {
            // Nothing outlives the intent an extension was launched for; the app's next update
            // reads the same stored state and carries the change.
            return
        }

        let scheduled: (token: UUID, delay: TimeInterval)? = state.mutate { state in
            if let providers {
                for provider in providers where !state.isCovered(generation: generation, limitedTo: provider) {
                    let key = ObjectIdentifier(provider)
                    let newest = max(state.limitedFailed[key]?.generation ?? 0, generation)
                    state.limitedFailed[key] = Failed(provider: provider, generation: newest)
                }
            } else if !state.isCovered(generation: generation, limitedTo: nil) {
                state.fullFailedAt = max(state.fullFailedAt ?? 0, generation)
            }

            guard state.hasWork, state.pendingToken == nil else { return nil }
            let token = UUID()
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
        let scope: [SensorProvider.Type]?? = state.mutate { state in
            // A success since it was scheduled disowned it.
            guard state.pendingToken == token, state.hasWork else { return nil }
            state.pendingToken = nil
            return .some(state.scope)
        }
        guard let scope else { return }
        perform(scope).cauterize()
    }

    /// Runs the block after the delay, keeping the app alive meanwhile when asked to. Should iOS
    /// end the background task before the delay is up, the wait carries on and the block runs
    /// once the app is running again.
    static func wait(_ delay: TimeInterval, holdingBackgroundTask: Bool, then block: @escaping () -> Void) {
        let waited = after(seconds: delay)
        guard holdingBackgroundTask else {
            waited.done { _ in block() }
            return
        }
        Current.backgroundTask(withName: BackgroundTask.sensorUpdateRetry.rawValue) { _ -> Promise<Void> in
            Promise { seal in
                waited.done { _ in
                    block()
                    seal.fulfill(())
                }
            }
        }.cauterize()
    }
}
