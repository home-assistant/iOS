import Foundation

// Event subscriptions as AsyncThrowingStreams with automatic resubscribe after reconnect.
public extension HAAPIConnection {
    /// Subscribes and streams typed events. The stream throws on a failed subscription result,
    /// an event decode failure, or `disconnect()`; consumer cancellation sends
    /// `unsubscribe_events` if still connected. Reconnects re-issue the subscription
    /// transparently — the stream just keeps yielding.
    func subscribe<S: HAAPISubscriptionProtocol>(_ subscription: S) -> AsyncThrowingStream<S.Event, any Error> {
        let token = UUID()
        let (stream, continuation) = AsyncThrowingStream<S.Event, any Error>.makeStream()
        subscriptionRecords[token] = SubscriptionRecord(
            command: subscription.command,
            data: subscription.data,
            yieldEvent: { frame in
                let envelope = try HAAPIConnection.makeDecoder().decode(EventEnvelope<S.Event>.self, from: frame)
                continuation.yield(envelope.event)
            },
            finish: { error in
                continuation.finish(throwing: error)
            },
            serverID: nil
        )
        continuation.onTermination = { _ in
            Task { await self.subscriptionTerminated(token: token) }
        }
        if case .connected = stateValue {
            Task { await self.transmitSubscription(token: token) }
        }
        return stream
    }

    /// Untyped variant yielding each event as a JSON value.
    func subscribe(
        command: String,
        data: [String: HAAPIJSONValue] = [:]
    ) -> AsyncThrowingStream<HAAPIJSONValue, any Error> {
        subscribe(HAAPISubscription<HAAPIJSONValue>(command: command, data: data))
    }
}

extension HAAPIConnection {
    func transmitSubscription(token: UUID) async {
        guard var record = subscriptionRecords[token],
              record.serverID == nil,
              case .connected = stateValue,
              let transport else { return }
        let id = takeNextCommandID()
        record.serverID = id
        subscriptionRecords[token] = record
        subscriptionTokensByServerID[id] = token
        do {
            let text = try ClientMessage(id: id, type: record.command, data: record.data).encodedText()
            try await transport.send(text: text)
        } catch {
            // Transport failure: the receive loop triggers reconnect, which re-issues this record.
        }
    }

    func subscriptionTerminated(token: UUID) async {
        guard let record = subscriptionRecords.removeValue(forKey: token) else { return }
        guard let id = record.serverID else { return }
        subscriptionTokensByServerID[id] = nil
        guard case .connected = stateValue, let transport else { return }
        let message = ClientMessage(
            id: takeNextCommandID(),
            type: "unsubscribe_events",
            data: ["subscription": .int(id)]
        )
        if let text = try? message.encodedText() {
            try? await transport.send(text: text)
        }
    }
}
