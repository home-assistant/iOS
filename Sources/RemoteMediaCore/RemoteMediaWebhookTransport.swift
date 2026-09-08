import Foundation

/// One `URLSession` for the length of a command and its read-backs, then released.
///
/// A burst is the natural scope: a command and its read-backs share one connection, while the
/// process holds no session between commands.
public final class RemoteMediaWebhookTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var session: URLSession?

    public init() {}

    public func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let session = currentSession()
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw RemoteMediaWebhookClient.ClientError.invalidResponse
        }
        return (data, response)
    }

    /// Ends the burst. Safe to call more than once, and a later request simply starts a new one.
    public func invalidate() {
        lock.lock()
        let session = session
        self.session = nil
        lock.unlock()
        session?.finishTasksAndInvalidate()
    }

    private func currentSession() -> URLSession {
        lock.lock()
        defer { lock.unlock() }
        if let session { return session }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = RemoteMediaWebhookClient.timeout
        configuration.waitsForConnectivity = false
        // An ephemeral session still keeps an in-memory response cache, which is dead weight in a
        // process that never reads a response twice.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        self.session = session
        return session
    }
}
