import Foundation
import PromiseKit

extension Promise {
    /// Bridges a promise into async/await, optionally failing once `seconds` have elapsed.
    ///
    /// Requests that travel over the WebSocket carry no deadline of their own, so a connection that
    /// never comes up would otherwise leave the caller — an App Intent, a widget timeline — hanging
    /// until the system kills it.
    ///
    /// Deliberately not called `async()`: PromiseKit vends its own bridging under that name and the
    /// extension targets carry a copy too, so a third one would make every call site ambiguous. This
    /// one stays internal to `Shared`.
    func asyncValue(timeout seconds: TimeInterval? = nil) async throws -> T {
        let promise: Promise<T>
        if let seconds {
            let deadline = after(seconds: seconds).then {
                Promise<T>(error: ShortcutAppIntentError(L10n.AppIntents.Error.timedOut(Int(seconds))))
            }
            promise = race(self, deadline)
        } else {
            promise = self
        }

        return try await withCheckedThrowingContinuation { continuation in
            promise.pipe { result in
                switch result {
                case let .fulfilled(value):
                    continuation.resume(returning: value)
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
