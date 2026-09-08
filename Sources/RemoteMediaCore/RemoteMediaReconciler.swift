import Foundation

/// Reads a player's state back after a command, until the command's effect shows up.
///
/// `call_service` returning 200 only means Home Assistant accepted it; an Echo's state can lag by a
/// second or more. Without this the extension sends Next, the Echo changes track, and the Now
/// Playing card keeps showing the old song until the containing app happens to be opened.
///
/// Bounded on purpose: a fixed, short ladder of attempts, never an open-ended poll.
///
/// **Transitional.** The authoritative mechanism is a `nowplaying` APNs update from Home Assistant,
/// proven on device to reach this extension — and to cold-launch it — while the containing app is
/// not running. This ladder only exists because the server cannot send those pushes yet: it is a
/// latency fast path for a process that happens to be alive, not background synchronization. When
/// the server path lands, the intended command flow is one `call_service` POST, an optimistic local
/// mutation where the result is knowable (play, pause, stop, seek, volume), and the authoritative
/// state arriving by push; `next`/`previous` keep showing the current track until it does, rather
/// than inventing the next track's metadata. This ladder should then shrink to at most one delayed
/// fallback read for a push that never arrived. Where a read-back and a later push overlap, the
/// newest authoritative state wins.
public struct RemoteMediaReconciler: Sendable {
    /// When to look, measured from the command completing. Short enough to feel immediate, spread
    /// wide enough to catch a cloud integration that answers late.
    public static let attemptDelays: [Duration] = [
        .milliseconds(250),
        .milliseconds(750),
        .milliseconds(1500),
        .milliseconds(2500),
    ]

    public typealias Fetch = @Sendable () async throws -> RemoteMediaStateReadback

    private let fetch: Fetch
    private let delays: [Duration]

    public init(delays: [Duration] = RemoteMediaReconciler.attemptDelays, fetch: @escaping Fetch) {
        self.delays = delays
        self.fetch = fetch
    }

    /// The last state read, whether or not it settled — a late-but-real report still beats showing
    /// the previous track. `nil` when nothing could be read at all.
    public func reconcile(
        until condition: RemoteMediaSettleCondition,
        onUpdate: @Sendable (RemoteMediaStateReadback) async -> Void
    ) async {
        for delay in delays {
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }

            let readback: RemoteMediaStateReadback
            do {
                readback = try await fetch()
            } catch {
                RemoteMediaLog.logger.debug("reconcile fetch failed, will retry if attempts remain")
                continue
            }
            if Task.isCancelled { return }

            switch readback {
            case let .entity(state):
                await onUpdate(readback)
                if condition.isSettled(state.snapshot) { return }
            case .missing:
                // Terminal: the entity is gone, so there is nothing left to settle.
                await onUpdate(readback)
                return
            case .unreadable:
                continue
            }
        }
    }
}
