import Foundation

// The connect/auth/reconnect supervisor and the heartbeat.
extension HAAPIConnection {
    func runSupervisor(runID: UUID) async {
        // Only clear the reference if it still belongs to this run: after `disconnect()` +
        // `connect()`, this (cancelled) supervisor may finish AFTER a new one started, and must
        // not wipe the new run's task reference.
        defer {
            if supervisorRunID == runID {
                supervisorTask = nil
                supervisorRunID = nil
            }
        }
        while !Task.isCancelled {
            do {
                try await runConnection(runID: runID)
                return
            } catch {
                if error is CancellationError || Task.isCancelled {
                    return
                }
                if case let HAAPIError.authenticationFailed(message) = error {
                    failAllRequests(with: .authenticationFailed(message: message))
                    finishAllSubscriptions(throwing: error)
                    setState(.disconnected(reason: .authenticationFailed(message: message)))
                    return
                }
                prepareForReconnect()
                reconnectAttempt += 1
                setState(.disconnected(reason: .waitingToReconnect(
                    attempt: reconnectAttempt,
                    errorDescription: String(describing: error)
                )))
                do {
                    try await Task.sleep(for: configuration.reconnectPolicy.delay(forAttempt: reconnectAttempt))
                } catch {
                    return
                }
            }
        }
    }

    /// One full connection attempt: connect, authenticate, serve until the socket dies.
    /// Only returns by throwing (or via cancellation).
    private func runConnection(runID: UUID) async throws {
        setState(.connecting)
        let url: URL
        do {
            url = try await configuration.webSocketURLProvider()
        } catch {
            throw HAAPIError.invalidConfiguration(description: "URL provider failed: \(error)")
        }
        var request = URLRequest(url: url)
        for (header, value) in configuration.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        let session = configuration.sessionProvider()
        defer { session.finishTasksAndInvalidate() }

        let transport = transportFactory.makeTransport(request: request, session: session)
        self.transport = transport
        defer {
            // Always close the transport this attempt opened, but only touch the shared state
            // (heartbeat, transport reference) while this run is still the current one — a stale
            // run's late cleanup must not tear down a newer session's.
            transport.close(code: .normalClosure)
            if supervisorRunID == runID {
                stopHeartbeat()
                self.transport = nil
            }
        }

        try await authenticate(on: transport)
        reconnectAttempt = 0
        startHeartbeat()
        await transmitBacklog()

        while true {
            try Task.checkCancellation()
            let frame = try await transport.receive()
            route(frame)
        }
    }

    private func authenticate(on transport: any HAAPITransport) async throws {
        while true {
            let frame = try await transport.receive()
            let (_, envelope) = try Self.parseEnvelope(frame)
            switch envelope.type {
            case "auth_required":
                setState(.authenticating)
                let token: String
                do {
                    token = try await configuration.accessTokenProvider()
                } catch {
                    throw HAAPIError.invalidConfiguration(description: "Token provider failed: \(error)")
                }
                let message = ClientMessage(id: nil, type: "auth", data: ["access_token": .string(token)])
                try await transport.send(text: message.encodedText())
            case "auth_ok":
                setState(.connected(haVersion: envelope.haVersion ?? "unknown"))
                return
            case "auth_invalid":
                throw HAAPIError.authenticationFailed(message: envelope.message)
            default:
                continue
            }
        }
    }

    /// After a drop: unsent state for everything that survives, failure for what doesn't.
    private func prepareForReconnect() {
        var kept: [UUID: PendingRequest] = [:]
        for (token, record) in requestRecords {
            var record = record
            record.serverID = nil
            if record.requeuesOnReconnect {
                kept[token] = record
            } else {
                record.continuation.resume(throwing: HAAPIError.transport(description: "Connection lost"))
            }
        }
        requestRecords = kept
        requestTokensByServerID = [:]

        for (token, record) in subscriptionRecords {
            var record = record
            record.serverID = nil
            record.isConfirmed = false
            subscriptionRecords[token] = record
        }
        subscriptionTokensByServerID = [:]
    }

    // MARK: - Heartbeat

    func startHeartbeat() {
        stopHeartbeat()
        let interval = configuration.heartbeatInterval
        let timeout = configuration.heartbeatTimeout
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                let responded = await performPing(timeout: timeout)
                if Task.isCancelled { return }
                if !responded {
                    await heartbeatTimedOut()
                    return
                }
            }
        }
    }

    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func heartbeatTimedOut() {
        // Closing the socket makes the receive loop throw, which routes into the reconnect path.
        transport?.close(code: .goingAway)
    }

    private func performPing(timeout: Duration) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await (try? self.sendAwaitingResult(command: "ping", data: [:], requeuesOnReconnect: false)) != nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}
