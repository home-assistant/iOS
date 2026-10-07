import Foundation
import PromiseKit

extension Promise {
    /// `asyncValue()` with a deadline.
    ///
    /// Requests that travel over the WebSocket carry no deadline of their own, so a connection that
    /// never comes up would otherwise leave the caller — an App Intent, a widget timeline — hanging
    /// until the system kills it.
    ///
    /// Deliberately takes no default: `HANetworking` already vends the plain `asyncValue()`, and a
    /// defaulted parameter here would make every `asyncValue()` call site ambiguous between the two.
    func asyncValue(timeout seconds: TimeInterval) async throws -> T {
        let deadline = after(seconds: seconds).then {
            Promise<T>(error: ShortcutAppIntentError(L10n.AppIntents.Error.timedOut(Int(seconds))))
        }
        return try await race(self, deadline).asyncValue()
    }
}
