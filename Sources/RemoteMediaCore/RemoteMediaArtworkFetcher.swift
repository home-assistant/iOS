import Foundation

/// Fetches album art from a credential-free absolute HTTPS source.
///
/// The host app cannot prepare artwork while it is not running, so the extension may fetch a
/// public source when the system asks for a cold track. The extension has no Companion credentials
/// and never adds any to these requests.
public enum RemoteMediaArtworkFetcher {
    /// Enough for a comfortably large album cover while leaving room in the extension's 6144 KB
    /// ledger for ImageIO and Now Playing. The limit is enforced as bytes arrive.
    public static let maximumBytes = 2 * 1024 * 1024
    /// Well inside the watchdog. Artwork is optional; being late is worse than being absent.
    public static let timeout: TimeInterval = 3

    /// The bytes and bounded diagnostic result of one artwork request.
    public struct Outcome: Sendable {
        public let data: Data?
        public let status: Int?
        public let mimeType: String?
        public let byteCount: Int
        public let reason: String
    }

    enum BodyRead: Equatable {
        case complete(Data)
        case tooLarge(byteCount: Int)
    }

    /// Whether this URL is syntactically eligible. The async fetch performs DNS validation too.
    public static func isFetchable(_ url: URL) -> Bool {
        RemoteMediaArtworkDestinationValidator.hasAllowedSyntax(url)
    }

    /// The image bytes, or an outcome saying why there are none.
    ///
    /// Never throws: artwork is optional and no failure of it may fail a session.
    public static func fetch(from url: URL) async -> Outcome {
        await fetch(
            from: url,
            configuration: sessionConfiguration(),
            validator: .init()
        )
    }

    static func fetch(
        from url: URL,
        configuration: URLSessionConfiguration,
        validator: RemoteMediaArtworkDestinationValidator
    ) async -> Outcome {
        guard await validator.allows(url) else {
            return .init(data: nil, status: nil, mimeType: nil, byteCount: 0, reason: "refused source")
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.httpShouldHandleCookies = false

        let redirectDelegate = RedirectDelegate(validator: validator)
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: redirectDelegate)
            let http = response as? HTTPURLResponse
            let mime = http?.mimeType

            if redirectDelegate.refusedRedirect {
                session.invalidateAndCancel()
                return .init(
                    data: nil,
                    status: http?.statusCode,
                    mimeType: mime,
                    byteCount: 0,
                    reason: "refused redirect"
                )
            }
            guard let http, http.statusCode == 200 else {
                session.invalidateAndCancel()
                return .init(
                    data: nil,
                    status: http?.statusCode,
                    mimeType: mime,
                    byteCount: 0,
                    reason: "status"
                )
            }
            if response.expectedContentLength > maximumBytes {
                session.invalidateAndCancel()
                return .init(
                    data: nil,
                    status: 200,
                    mimeType: mime,
                    byteCount: Int(response.expectedContentLength),
                    reason: "too large"
                )
            }

            switch try await boundedData(from: bytes, maximumBytes: maximumBytes) {
            case let .complete(data) where data.isEmpty:
                return .init(data: nil, status: 200, mimeType: mime, byteCount: 0, reason: "empty")
            case let .complete(data):
                return .init(data: data, status: 200, mimeType: mime, byteCount: data.count, reason: "ok")
            case let .tooLarge(byteCount):
                session.invalidateAndCancel()
                return .init(
                    data: nil,
                    status: 200,
                    mimeType: mime,
                    byteCount: byteCount,
                    reason: "too large"
                )
            }
        } catch {
            session.invalidateAndCancel()
            return .init(
                data: nil,
                status: nil,
                mimeType: nil,
                byteCount: 0,
                reason: Task.isCancelled ? "cancelled" : "unreachable"
            )
        }
    }

    /// Reads no more than one byte beyond the limit, which is enough to prove the body is too big.
    static func boundedData<Bytes: AsyncSequence>(
        from bytes: Bytes,
        maximumBytes: Int
    ) async throws -> BodyRead where Bytes.Element == UInt8 {
        var data = Data()
        data.reserveCapacity(min(maximumBytes, 64 * 1024))
        var count = 0
        for try await byte in bytes {
            count += 1
            guard count <= maximumBytes else { return .tooLarge(byteCount: count) }
            data.append(byte)
        }
        return .complete(data)
    }

    /// The same full destination policy is applied to every redirect before Foundation follows it.
    static func shouldFollowRedirect(
        to request: URLRequest,
        validator: RemoteMediaArtworkDestinationValidator
    ) async -> Bool {
        guard let url = request.url else { return false }
        return await validator.allows(url)
    }

    /// The image bytes, or `nil`. Kept for callers that have nothing to say about a failure.
    public static func data(from url: URL) async -> Data? {
        await fetch(from: url).data
    }

    private static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        return configuration
    }

    private final class RedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let validator: RemoteMediaArtworkDestinationValidator
        private let lock = NSLock()
        private var didRefuseRedirect = false

        init(validator: RemoteMediaArtworkDestinationValidator) {
            self.validator = validator
        }

        var refusedRedirect: Bool {
            lock.lock()
            defer { lock.unlock() }
            return didRefuseRedirect
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            Task { [validator] in
                let allowed = await RemoteMediaArtworkFetcher.shouldFollowRedirect(
                    to: request,
                    validator: validator
                )
                if !allowed {
                    lock.lock()
                    didRefuseRedirect = true
                    lock.unlock()
                }
                completionHandler(allowed ? request : nil)
            }
        }
    }
}
