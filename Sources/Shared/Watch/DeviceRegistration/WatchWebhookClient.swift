import Foundation

/// Sends webhook requests through the watch's own registration.
///
/// `WebhookManager` speaks for the registration in `ConnectionInfo`, which on the watch is the
/// paired iPhone's, mirrored. Now that the watch is a `mobile_app` device of its own, what it reports
/// about itself goes through its own webhook — same encryption, same cloudhook rule, own identity.
public enum WatchWebhookClient {
    public enum WebhookError: LocalizedError, Equatable {
        /// The registration no longer exists on the server — the device was deleted there. A 404 or
        /// 410 from the cloudhook, or an empty 200 from Home Assistant directly.
        case registrationGone
        case unacceptableStatus(code: Int)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .registrationGone:
                return "The watch is no longer registered with the server"
            case let .unacceptableStatus(code):
                return "The server answered with status \(code)"
            case .invalidResponse:
                return "The server's response could not be read"
            }
        }
    }

    /// Where to post: the cloudhook whenever the active URL isn't the server's internal one,
    /// otherwise the webhook path on the active URL — the same choice `ConnectionInfo` makes for
    /// the phone's registration. Decided by URL type rather than by comparing URLs, which differ in
    /// normalization (the active URL is sanitized, the stored one isn't).
    public static func webhookURL(
        activeURL: URL,
        activeURLType: ConnectionInfo.URLType,
        registration: WatchDeviceRegistration
    ) -> URL {
        if let cloudhookURL = registration.cloudhookURL, activeURLType != .internal {
            return cloudhookURL
        }
        return activeURL.appendingPathComponent(registration.webhookPath, isDirectory: false)
    }

    /// The request body: sealed when the registration has a secret, plain otherwise.
    public static func body(type: String, data: Any, secret: [UInt8]?) throws -> [String: Any] {
        var body: [String: Any] = ["type": type]
        if let secret {
            body["encrypted"] = true
            body["encrypted_data"] = try WebhookPayloadCrypto.encrypt(data, secret: secret)
        } else {
            body["data"] = data
        }
        return body
    }

    /// The response's JSON, unsealed when the server encrypted it; `()` for an empty body.
    public static func responseObject(from data: Data, secret: [UInt8]?) throws -> Any {
        guard !data.isEmpty else { return () }

        let object = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
        guard let dictionary = object as? [String: Any],
              let encoded = dictionary["encrypted_data"] as? String else {
            return object
        }
        guard let secret else {
            throw WebhookJsonParseError.missingKey
        }
        return try WebhookPayloadCrypto.decrypt(encoded, secret: secret)
    }

    /// Performs a request against the server's mTLS-aware session and returns the raw response.
    public typealias Perform = (URLRequest, Server) async throws -> (Data, HTTPURLResponse)

    /// Posts one webhook request and returns the decoded response.
    ///
    /// - Parameter perform: how the request reaches the network; the server's certificate-aware
    ///   `URLSession` unless a test substitutes a fake.
    public static func send(
        type: String,
        data: Any,
        server: Server,
        registration: WatchDeviceRegistration,
        timeout: TimeInterval = HomeAssistantRESTClient.defaultTimeout,
        perform: Perform = WatchWebhookClient.perform
    ) async throws -> Any {
        // Synchronous URL evaluation on purpose — see `MagicItem.executeViaREST`. Evaluating also
        // writes the chosen URL type back to the server, which is what's read next.
        guard let activeURL = server.activeURLUsingLastKnownNetworkState() else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }

        let url = webhookURL(
            activeURL: activeURL,
            activeURLType: server.info.connection.activeURLType,
            registration: registration
        )
        let secret = registration.webhookSecretBytes(version: server.info.version)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body(type: type, data: data, secret: secret),
            options: [.sortedKeys]
        )

        Current.Log.info("sending \(type) to \(server.info.name) through the watch registration")
        let (responseData, response) = try await perform(request, server)

        switch response.statusCode {
        case 404, 410:
            throw WebhookError.registrationGone
        case 400...:
            throw WebhookError.unacceptableStatus(code: response.statusCode)
        default:
            return try responseObject(from: responseData, secret: secret)
        }
    }

    /// The real transport: the server's certificate-aware session.
    public static func perform(_ request: URLRequest, server: Server) async throws -> (Data, HTTPURLResponse) {
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        // The session strongly retains its delegate until invalidated; do it once the task ends.
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: WebhookError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data ?? Data(), response))
            }.resume()
        }
    }
}
