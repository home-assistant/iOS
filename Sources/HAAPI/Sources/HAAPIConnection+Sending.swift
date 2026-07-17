import Foundation

// Typed and untyped command sending with id correlation and pre-auth queueing.
public extension HAAPIConnection {
    /// Sends a command and decodes its `result`. Suspends until connected+authenticated if
    /// necessary, survives reconnects (the command is re-sent with a fresh id), and honors task
    /// cancellation.
    func send<R: HAAPIRequestProtocol>(_ request: R) async throws -> R.Response {
        let frame = try await sendAwaitingResult(
            command: request.command,
            data: request.data,
            requeuesOnReconnect: true
        )
        do {
            return try Self.makeDecoder().decode(ResultEnvelope<R.Response>.self, from: frame).result
        } catch {
            throw HAAPIError.decoding(command: request.command, description: String(describing: error))
        }
    }

    /// Untyped variant returning the raw `result` as a JSON value — the bridge for callers that
    /// decode with their own machinery.
    func send(command: String, data: [String: HAAPIJSONValue] = [:]) async throws -> HAAPIJSONValue {
        try await send(HAAPIRequest<HAAPIJSONValue>(command: command, data: data))
    }
}

extension HAAPIConnection {
    /// Returns the raw frame data of the successful `result`/`pong` for this command.
    func sendAwaitingResult(
        command: String,
        data: [String: HAAPIJSONValue],
        requeuesOnReconnect: Bool
    ) async throws -> Data {
        let token = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                registerRequest(
                    token: token,
                    command: command,
                    data: data,
                    requeuesOnReconnect: requeuesOnReconnect,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task { await self.cancelRequest(token: token) }
        }
    }

    private func registerRequest(
        token: UUID,
        command: String,
        data: [String: HAAPIJSONValue],
        requeuesOnReconnect: Bool,
        continuation: CheckedContinuation<Data, any Error>
    ) {
        guard !Task.isCancelled else {
            continuation.resume(throwing: HAAPIError.cancelled)
            return
        }
        requestRecords[token] = PendingRequest(
            command: command,
            data: data,
            requeuesOnReconnect: requeuesOnReconnect,
            continuation: continuation,
            serverID: nil
        )
        if case .connected = stateValue {
            Task { await self.transmitRequest(token: token) }
        }
    }

    func transmitRequest(token: UUID) async {
        guard var record = requestRecords[token],
              record.serverID == nil,
              case .connected = stateValue,
              let transport else { return }
        let id = takeNextCommandID()
        record.serverID = id
        requestRecords[token] = record
        requestTokensByServerID[id] = token
        do {
            let text = try ClientMessage(id: id, type: record.command, data: record.data).encodedText()
            try await transport.send(text: text)
        } catch let error as EncodingError {
            requestRecords[token] = nil
            requestTokensByServerID[id] = nil
            record.continuation.resume(throwing: HAAPIError.decoding(
                command: record.command,
                description: String(describing: error)
            ))
        } catch {
            // Transport failure: the receive loop notices the dead socket and triggers the
            // reconnect path, which requeues (or fails) this record.
            if !record.requeuesOnReconnect {
                requestRecords[token] = nil
                requestTokensByServerID[id] = nil
                record.continuation.resume(throwing: HAAPIError.transport(description: String(describing: error)))
            }
        }
    }

    private func cancelRequest(token: UUID) {
        guard let record = requestRecords.removeValue(forKey: token) else { return }
        if let id = record.serverID {
            requestTokensByServerID[id] = nil
        }
        record.continuation.resume(throwing: HAAPIError.cancelled)
    }

    /// Sends everything queued while disconnected and re-issues surviving subscriptions.
    func transmitBacklog() async {
        for token in requestRecords.keys where requestRecords[token]?.serverID == nil {
            await transmitRequest(token: token)
        }
        for token in subscriptionRecords.keys where subscriptionRecords[token]?.serverID == nil {
            await transmitSubscription(token: token)
        }
    }

    // MARK: - Incoming frame routing

    func route(_ frame: HAAPITransportMessage) {
        guard let (data, envelope) = try? Self.parseEnvelope(frame) else { return }
        switch envelope.type {
        case "result":
            guard let id = envelope.id else { return }
            if let token = requestTokensByServerID.removeValue(forKey: id),
               let record = requestRecords.removeValue(forKey: token) {
                if envelope.success == false {
                    record.continuation.resume(throwing: HAAPIError.server(
                        code: envelope.error?.code ?? "unknown",
                        message: envelope.error?.message ?? ""
                    ))
                } else {
                    record.continuation.resume(returning: data)
                }
            } else if let token = subscriptionTokensByServerID[id],
                      var record = subscriptionRecords[token] {
                if envelope.success == false {
                    subscriptionTokensByServerID[id] = nil
                    subscriptionRecords[token] = nil
                    record.finish(HAAPIError.server(
                        code: envelope.error?.code ?? "unknown",
                        message: envelope.error?.message ?? ""
                    ))
                } else {
                    record.isConfirmed = true
                    subscriptionRecords[token] = record
                }
            }
        case "event":
            guard let id = envelope.id,
                  let token = subscriptionTokensByServerID[id],
                  let record = subscriptionRecords[token] else { return }
            do {
                try record.yieldEvent(data)
            } catch {
                subscriptionTokensByServerID[id] = nil
                subscriptionRecords[token] = nil
                record.finish(HAAPIError.decoding(
                    command: record.command,
                    description: String(describing: error)
                ))
            }
        case "pong":
            guard let id = envelope.id,
                  let token = requestTokensByServerID.removeValue(forKey: id),
                  let record = requestRecords.removeValue(forKey: token) else { return }
            record.continuation.resume(returning: data)
        default:
            // Unknown frame types are ignored for forward compatibility.
            break
        }
    }
}
