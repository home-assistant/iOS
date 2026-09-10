import Foundation

/// Owns the webhook resources for one media command and its bounded state reconciliation.
///
/// A burst is intentionally not shared between commands. Cancelling an older reconciliation can
/// therefore release only its own session, never the connection a newer command is using.
public final class RemoteMediaCommandBurst: @unchecked Sendable {
    private let client: RemoteMediaWebhookClient
    private let lock = NSLock()
    private var isFinished = false

    public init(client: RemoteMediaWebhookClient = .init()) {
        self.client = client
    }

    deinit {
        finish()
    }

    /// Sends the command, releasing the burst immediately if delivery fails or is cancelled.
    public func send(
        _ command: RemoteMediaCommand,
        value: Double? = nil,
        selection: RemoteMediaSelection,
        context: RemoteMediaTransportContext
    ) async throws {
        do {
            try await client.send(command, value: value, selection: selection, context: context)
        } catch {
            finish()
            throw error
        }
    }

    /// Owns the client until reconciliation finishes on success, failure or cancellation.
    public func reconcile(
        selection: RemoteMediaSelection,
        context: RemoteMediaTransportContext,
        until condition: RemoteMediaSettleCondition,
        delays: [Duration] = RemoteMediaReconciler.attemptDelays,
        onUpdate: @escaping @Sendable (RemoteMediaStateReadback) async -> Void
    ) async {
        defer { finish() }
        await RemoteMediaReconciler(delays: delays) { [client] in
            try await client.readState(selection: selection, context: context)
        }.reconcile(until: condition, onUpdate: onUpdate)
    }

    /// Idempotent so cancellation and normal task completion may race without double cleanup.
    public func finish() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()
        client.endBurst()
    }
}
