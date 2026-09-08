import Foundation

/// Posts one registration, retrying only as long as the failure looks like the network's fault.
///
/// A registration is important but never load-bearing: the Now Playing card the user is looking at
/// is already on screen, and the commands it offers already work. So the budget is small and fixed
/// — an immediate attempt and a couple of backed-off retries — with no timer left running behind
/// it. The natural retry opportunity is the next time the extension or the session is recreated,
/// which happens often enough on its own that a process with a 6144 KB ledger need not keep waking
/// to ask again.
@MainActor
public final class RemoteMediaRegistrationSender {
    /// How the attempt ended, so the caller can decide whether the token is still owed to the
    /// server without having to interpret transport errors itself.
    public enum Outcome: Equatable, Sendable {
        /// Home Assistant accepted the request. Not a promise that it understood it: a server
        /// without the matching Core support answers an unknown webhook type with an empty 200.
        case delivered(attempts: Int)
        /// The server answered and refused. Sending the same bytes again cannot change that.
        case refused
        /// Nothing answered before the budget ran out. Still owed.
        case unreachable(attempts: Int)
        /// A newer Follow lifetime took over while this was in flight.
        case superseded
    }

    public typealias Perform = @Sendable (
        RemoteMediaSessionRegistration,
        RemoteMediaTransportContext
    ) async throws -> Void

    /// Short enough that a phone which regained its network mid-attempt still succeeds, few enough
    /// that a phone which did not is left alone.
    public static let defaultRetryDelays: [Duration] = [.seconds(2), .seconds(8)]

    /// One request-scoped session per attempt, released as soon as it replies. The same reasoning
    /// as `RemoteMediaWebhookTransport`: a registration is a single POST, and holding a connection
    /// open between backed-off retries costs the ledger more than the handshake does.
    public static let live: Perform = { registration, context in
        let client = RemoteMediaWebhookClient()
        defer { client.endBurst() }
        try await client.register(registration, context: context)
    }

    private let perform: Perform
    private let retryDelays: [Duration]
    private var task: Task<Void, Never>?

    public init(
        retryDelays: [Duration] = RemoteMediaRegistrationSender.defaultRetryDelays,
        perform: @escaping Perform = RemoteMediaRegistrationSender.live
    ) {
        self.retryDelays = retryDelays
        self.perform = perform
    }

    /// Sends `registration`, replacing whatever was still in flight.
    ///
    /// `isCurrent` is consulted before every attempt, so a registration whose Follow lifetime ended
    /// while it was waiting to retry is abandoned rather than handed to the server late.
    public func send(
        _ registration: RemoteMediaSessionRegistration,
        context: RemoteMediaTransportContext,
        isCurrent: @escaping @MainActor () -> Bool,
        onOutcome: @escaping @MainActor (Outcome) -> Void
    ) {
        task?.cancel()
        task = Task { [perform, retryDelays] in
            for attempt in 0 ... retryDelays.count {
                if attempt > 0 {
                    do {
                        try await Task.sleep(for: retryDelays[attempt - 1])
                    } catch {
                        onOutcome(.superseded)
                        return
                    }
                }
                guard !Task.isCancelled else {
                    onOutcome(.superseded)
                    return
                }
                guard isCurrent() else {
                    onOutcome(.superseded)
                    return
                }
                do {
                    try await perform(registration, context)
                    onOutcome(.delivered(attempts: attempt + 1))
                    return
                } catch {
                    guard Self.isWorthRetrying(error) else {
                        onOutcome(.refused)
                        return
                    }
                }
            }
            onOutcome(.unreachable(attempts: retryDelays.count + 1))
        }
    }

    /// Abandons whatever is in flight. The local session is unaffected: the user is still following
    /// this player whether or not the server ever learned the token.
    public func cancel() {
        task?.cancel()
        task = nil
    }

    /// Only a failure the network could plausibly stop causing. A refusal means the server read the
    /// request and said no, and repeating it would just be noise.
    static func isWorthRetrying(_ error: Error) -> Bool {
        switch error {
        case is URLError:
            return true
        case let RemoteMediaWebhookClient.ClientError.unacceptableStatus(code):
            return code >= 500
        default:
            return false
        }
    }
}
