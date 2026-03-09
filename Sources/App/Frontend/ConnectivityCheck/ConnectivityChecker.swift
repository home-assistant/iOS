import Foundation
import Network

@MainActor
class ConnectivityChecker {
    private let timeout: TimeInterval = 5.0
    private let state: ConnectivityCheckState

    init(state: ConnectivityCheckState) {
        self.state = state
    }

    func runChecks(for url: URL) async {
        state.isRunning = true
        defer { state.isRunning = false }

        // Extract components from URL
        guard let host = url.host else {
            markAllAsFailed(error: "Invalid URL: no host found")
            return
        }

        let port = url.port ?? (url.scheme == "https" ? 443 : 80)
        let isHTTPS = url.scheme == "https"

        // Run checks sequentially
        let dnsSuccess = await checkDNS(host: host)
        guard dnsSuccess else {
            // Skip remaining checks if DNS fails
            skipRemainingChecks(after: .dns)
            return
        }

        let portSuccess = await checkPort(host: host, port: port)
        guard portSuccess else {
            skipRemainingChecks(after: .port)
            return
        }

        if isHTTPS {
            await checkTLS(url: url)
        } else {
            state.updateCheck(type: .tls, result: .skipped)
        }

        await checkServer(url: url)
    }

    // MARK: - DNS Resolution Check

    private func checkDNS(host: String) async -> Bool {
        state.updateCheck(type: .dns, result: .running)

        do {
            let addresses = try await resolveDNS(host: host)
            let message = addresses.isEmpty ? nil : "Resolved to: \(addresses.joined(separator: ", "))"
            state.updateCheck(type: .dns, result: .success(message: message))
            return true
        } catch {
            state.updateCheck(type: .dns, result: .failure(error: error.localizedDescription))
            return false
        }
    }

    private func resolveDNS(host: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)

            var success: DarwinBoolean = false
            guard let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
                  success.boolValue else {
                continuation.resume(throwing: NSError(
                    domain: "ConnectivityChecker",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "DNS resolution failed"]
                ))
                return
            }

            let ipAddresses = addresses.compactMap { address -> String? in
                guard let data = address as? Data else {
                    return nil
                }
                var storage = sockaddr_storage()
                data.withUnsafeBytes { bytes in
                    memcpy(&storage, bytes.baseAddress!, min(bytes.count, MemoryLayout<sockaddr_storage>.size))
                }

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = withUnsafePointer(to: &storage) { storagePtr in
                    storagePtr.withMemoryRebound(to: Darwin.sockaddr.self, capacity: 1) { sockaddrPtr in
                        getnameinfo(
                            sockaddrPtr,
                            socklen_t(data.count),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        )
                    }
                }

                guard result == 0 else {
                    return nil
                }

                return String(cString: hostname)
            }

            continuation.resume(returning: ipAddresses)
        }
    }

    // MARK: - Port Reachability Check

    private func checkPort(host: String, port: Int) async -> Bool {
        state.updateCheck(type: .port, result: .running)

        do {
            try await testPort(host: host, port: port)
            state.updateCheck(
                type: .port,
                result: .success(message: "Port \(port) is reachable")
            )
            return true
        } catch {
            state.updateCheck(type: .port, result: .failure(error: error.localizedDescription))
            return false
        }
    }

    private func testPort(host: String, port: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "connectivity.port.check")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )

            var completed = false
            let timeoutTask = DispatchWorkItem {
                if !completed {
                    completed = true
                    connection.cancel()
                    continuation.resume(throwing: NSError(
                        domain: "ConnectivityChecker",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]
                    ))
                }
            }

            connection.stateUpdateHandler = { state in
                guard !completed else { return }

                switch state {
                case .ready:
                    completed = true
                    timeoutTask.cancel()
                    connection.cancel()
                    continuation.resume()
                case let .failed(error):
                    completed = true
                    timeoutTask.cancel()
                    connection.cancel()
                    continuation.resume(throwing: error)
                case let .waiting(error):
                    completed = true
                    timeoutTask.cancel()
                    connection.cancel()
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
        }
    }

    // MARK: - TLS Certificate Check

    private func checkTLS(url: URL) async {
        state.updateCheck(type: .tls, result: .running)

        do {
            try await validateTLSCertificate(url: url)
            state.updateCheck(type: .tls, result: .success(message: "Certificate is valid"))
        } catch {
            state.updateCheck(type: .tls, result: .failure(error: error.localizedDescription))
        }
    }

    private func validateTLSCertificate(url: URL) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)

        _ = try await session.data(for: request)
    }

    // MARK: - Server Connection Check

    private func checkServer(url: URL) async {
        state.updateCheck(type: .server, result: .running)

        do {
            let statusCode = try await testServerConnection(url: url)
            state.updateCheck(
                type: .server,
                result: .success(message: "Server responded with status \(statusCode)")
            )
        } catch {
            state.updateCheck(type: .server, result: .failure(error: error.localizedDescription))
        }
    }

    private func testServerConnection(url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "HEAD"

        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ConnectivityChecker",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
            )
        }

        return httpResponse.statusCode
    }

    // MARK: - Helper Methods

    private func markAllAsFailed(error: String) {
        for checkType in ConnectivityCheckType.allCases {
            state.updateCheck(type: checkType, result: .failure(error: error))
        }
    }

    private func skipRemainingChecks(after failedCheck: ConnectivityCheckType) {
        guard let failedIndex = ConnectivityCheckType.allCases.firstIndex(of: failedCheck) else {
            return
        }

        let remainingChecks = Array(ConnectivityCheckType.allCases.dropFirst(failedIndex + 1))
        for checkType in remainingChecks {
            state.updateCheck(type: checkType, result: .skipped)
        }
    }
}
