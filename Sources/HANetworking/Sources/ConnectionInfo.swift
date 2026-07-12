import Alamofire
import Foundation

public enum ConnectionSecurityLevel: String, Codable {
    // User has not opted in or out of security checks
    case undefined
    // Checks for home network before connecting to non-https URLs
    case mostSecure
    // Allows non-https URLs always
    case lessSecure

    // `description` (localized) lives in the Shared module (see HANetworkingLocalization.swift) since
    // L10n isn't available in this package.
}

public struct ConnectionInfo: Codable, Equatable {
    private var externalURL: URL?
    public private(set) var internalURL: URL?
    private var remoteUIURL: URL?
    public var webhookID: String
    public var webhookSecret: String?
    public var useCloud: Bool = false
    public var cloudhookURL: URL?
    public var connectionAccessSecurityLevel: ConnectionSecurityLevel = .undefined
    /// Client certificate for mTLS authentication (optional, iOS only)
    public var clientCertificate: ClientCertificate?
    public var internalSSIDs: [String]? {
        didSet {
            overrideActiveURLType = nil
        }
    }

    public var internalHardwareAddresses: [String]? {
        didSet {
            overrideActiveURLType = nil
        }
    }

    public var canUseCloud: Bool {
        remoteUIURL != nil
    }

    public var hasRemoteConnectionSetup: Bool {
        externalURL != nil || remoteUIURL != nil
    }

    private var configuredURLs: [URL] {
        [externalURL, internalURL, remoteUIURL].compactMap(\.self)
    }

    public var hasNonHTTPSURLOptions: Bool {
        configuredURLs.contains { $0.scheme?.lowercased() != "https" }
    }

    public var hasOnlyHTTPSURLOptions: Bool {
        guard !configuredURLs.isEmpty else {
            return false
        }

        return configuredURLs.allSatisfy { $0.scheme?.lowercased() == "https" }
    }

    public var overrideActiveURLType: URLType?
    public private(set) var activeURLType: URLType = .external

    public var isLocalPushEnabled = true {
        didSet {
            guard oldValue != isLocalPushEnabled else { return }
            HANetworkingEnvironment.current.log.verbose("updated local push from \(oldValue) to \(isLocalPushEnabled)")
        }
    }

    public var securityExceptions: SecurityExceptions = .init()
    public func evaluate(_ challenge: URLAuthenticationChallenge)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Handle client certificate challenge for mTLS
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let cert = clientCertificate {
                do {
                    let credential = try ClientCertificateManager.shared.urlCredential(for: cert)
                    HANetworkingEnvironment.current.log
                        .info("[mTLS] Using client certificate for webhook: \(cert.displayName)")
                    return (.useCredential, credential)
                } catch {
                    HANetworkingEnvironment.current.log.error("[mTLS] Failed to get credential: \(error)")
                    return (.cancelAuthenticationChallenge, nil)
                }
            } else {
                HANetworkingEnvironment.current.log.warning("[mTLS] Client certificate requested but none configured")
                return (.performDefaultHandling, nil)
            }
        }

        // Handle server trust and other challenges
        return securityExceptions.evaluate(challenge)
    }

    public init(
        externalURL: URL?,
        internalURL: URL?,
        cloudhookURL: URL?,
        remoteUIURL: URL?,
        webhookID: String,
        webhookSecret: String?,
        internalSSIDs: [String]?,
        internalHardwareAddresses: [String]?,
        isLocalPushEnabled: Bool,
        securityExceptions: SecurityExceptions,
        connectionAccessSecurityLevel: ConnectionSecurityLevel,
        clientCertificate: ClientCertificate? = nil
    ) {
        self.externalURL = externalURL
        self.internalURL = internalURL
        self.cloudhookURL = cloudhookURL
        self.remoteUIURL = remoteUIURL
        self.webhookID = webhookID
        self.webhookSecret = webhookSecret
        self.internalSSIDs = internalSSIDs
        self.internalHardwareAddresses = internalHardwareAddresses
        self.isLocalPushEnabled = isLocalPushEnabled
        self.securityExceptions = securityExceptions
        self.connectionAccessSecurityLevel = connectionAccessSecurityLevel
        self.clientCertificate = clientCertificate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.externalURL = try container.decodeIfPresent(URL.self, forKey: .externalURL)
        self.internalURL = try container.decodeIfPresent(URL.self, forKey: .internalURL)
        self.remoteUIURL = try container.decodeIfPresent(URL.self, forKey: .remoteUIURL)
        self.webhookID = try container.decode(String.self, forKey: .webhookID)
        self.webhookSecret = try container.decodeIfPresent(String.self, forKey: .webhookSecret)
        self.cloudhookURL = try container.decodeIfPresent(URL.self, forKey: .cloudhookURL)
        self.internalSSIDs = try container.decodeIfPresent([String].self, forKey: .internalSSIDs)
        self.internalHardwareAddresses =
            try container.decodeIfPresent([String].self, forKey: .internalHardwareAddresses)
        self.useCloud = try container.decodeIfPresent(Bool.self, forKey: .useCloud) ?? false
        self.connectionAccessSecurityLevel = try container.decodeIfPresent(
            ConnectionSecurityLevel.self,
            forKey: .connectionAccessSecurityLevel
        ) ?? .undefined
        self.isLocalPushEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLocalPushEnabled) ?? true
        self.securityExceptions = try container.decodeIfPresent(
            SecurityExceptions.self,
            forKey: .securityExceptions
        ) ?? .init()
        self.clientCertificate = try container.decodeIfPresent(
            ClientCertificate.self,
            forKey: .clientCertificate
        )
    }

    // Localized `description` (CustomStringConvertible) is added retroactively in the Shared module
    // (HANetworkingLocalization.swift) because L10n isn't available in this package.
    public enum URLType: Int, Codable, CaseIterable, CustomDebugStringConvertible {
        case `internal`
        case remoteUI
        case external
        case none

        public var debugDescription: String {
            switch self {
            case .internal:
                return "Internal URL"
            case .remoteUI:
                return "Remote UI"
            case .external:
                return "External URL"
            case .none:
                return "No URL (Active URL nil)"
            }
        }

        public var isAffectedBySSID: Bool {
            switch self {
            case .internal: return true
            case .remoteUI, .external, .none: return false
            }
        }

        public var isAffectedByCloud: Bool {
            switch self {
            case .internal: return false
            case .remoteUI, .external, .none: return true
            }
        }

        public var isAffectedByHardwareAddress: Bool {
            switch self {
            case .internal: return HANetworkingEnvironment.current.isCatalyst
            case .remoteUI, .external, .none: return false
            }
        }

        public var hasLocalPush: Bool {
            switch self {
            case .internal:
                if HANetworkingEnvironment.current.isCatalyst {
                    return false
                }
                return true
            default: return false
            }
        }
    }

    /// Returns the url that should be used at this moment to access the Home Assistant instance,
    /// refreshing network information (e.g. current SSID) before evaluating which URL is active.
    public mutating func activeURL() async -> URL? {
        await HANetworkingEnvironment.current.connectivity.refreshNetworkInformation()
        return evaluateActiveURL()
    }

    /// Evaluates the url that should be used at this moment to access the Home Assistant instance,
    /// based on the currently cached network information.
    ///
    /// Not meant for general use: prefer the async `activeURL()`, which refreshes network
    /// information first. This exists for callers that must stay synchronous and accept
    /// potentially stale network information.
    public mutating func evaluateActiveURL() -> URL? {
        if let overrideActiveURLType {
            let overrideURL: URL?

            switch overrideActiveURLType {
            case .internal:
                activeURLType = .internal
                overrideURL = internalURL
            case .remoteUI:
                activeURLType = .remoteUI
                overrideURL = remoteUIURL
            case .external:
                activeURLType = .external
                overrideURL = externalURL
            case .none:
                activeURLType = .none
                overrideURL = nil
            }

            if let overrideURL {
                return overrideURL.sanitized()
            }
        }

        let url: URL?

        if let internalURL, isOnInternalNetworkUsingLastKnownState || overrideActiveURLType == .internal {
            // Home network, local connection
            activeURLType = .internal
            url = internalURL
        } else if let remoteUIURL, useCloud {
            // Home Assistant Cloud connection
            activeURLType = .remoteUI
            url = remoteUIURL
        } else if let externalURL {
            // Custom remote connection
            activeURLType = .external
            url = externalURL
        } else if let internalURL, [.lessSecure, .undefined].contains(connectionAccessSecurityLevel) {
            // Falback to internal URL if no other URL is set
            // In case user opted to not check for home network or haven't made a decision yet
            // we allow usage of internal URL as fallback
            activeURLType = .internal
            url = internalURL
        } else if let internalURL, internalURL.scheme == "https" {
            // Falback to internal URL if no other URL is set and internal URL is HTTPS
            activeURLType = .internal
            url = internalURL
        } else {
            url = nil
            activeURLType = .none
        }

        return url?.sanitized()
    }

    /// Returns the url that should be used at this moment to share with someone else to access the Home Assistant
    /// instance.
    /// Cloud > Remote > Internal
    public func invitationURL() -> URL? {
        if useCloud, let remoteUIURL {
            return remoteUIURL.sanitized()
        } else if let externalURL {
            return externalURL.sanitized()
        } else if let internalURL {
            return internalURL.sanitized()
        } else {
            return nil
        }
    }

    /// Returns the activeURL with /api appended, refreshing network information (e.g. current SSID)
    /// before evaluating which URL is active.
    public mutating func activeAPIURL() async -> URL? {
        if let activeURL = await activeURL() {
            return activeURL.appendingPathComponent("api", isDirectory: false)
        } else {
            return nil
        }
    }

    /// Returns the url that should be used at this moment to reach the webhook, refreshing network
    /// information (e.g. current SSID) before evaluating which URL is active.
    public mutating func webhookURL() async -> URL? {
        await HANetworkingEnvironment.current.connectivity.refreshNetworkInformation()
        return evaluateWebhookURL()
    }

    /// Evaluates the url that should be used at this moment to reach the webhook, based on the
    /// currently cached network information.
    ///
    /// Not meant for general use: prefer the async `webhookURL()`, which refreshes network
    /// information first. This exists for callers that must stay synchronous and accept
    /// potentially stale network information.
    public mutating func evaluateWebhookURL() -> URL? {
        if let cloudhookURL, !isOnInternalNetworkUsingLastKnownState {
            return cloudhookURL
        }

        if let activeURL = evaluateActiveURL() {
            return activeURL.appendingPathComponent(webhookPath, isDirectory: false)
        } else {
            return nil
        }
    }

    public var webhookPath: String {
        "api/webhook/\(webhookID)"
    }

    public func address(for addressType: URLType) -> URL? {
        switch addressType {
        case .internal: return internalURL
        case .external: return externalURL
        case .remoteUI: return remoteUIURL
        case .none: return nil
        }
    }

    /// Returns a URL for troubleshooting purposes, such as displaying in error messages or running connectivity checks.
    /// This method provides read-only access to connection URLs that are otherwise private.
    /// - Parameter type: The type of URL to retrieve for troubleshooting
    /// - Returns: The URL for the specified type, if available
    public func urlForTroubleshooting(type: URLType) -> URL? {
        address(for: type)
    }

    public mutating func set(address: URL?, for addressType: URLType) {
        switch addressType {
        case .internal:
            internalURL = address
        case .external:
            externalURL = address
        case .remoteUI:
            remoteUIURL = address
        case .none:
            break
        }
    }

    /// Returns true if the current SSID (or hardware address) is marked for internal URL use,
    /// fetching fresh network information before evaluating.
    public func isOnInternalNetwork() async -> Bool {
        await isOnInternalNetwork(using: HANetworkingEnvironment.current.connectivity.currentNetworkState())
    }

    /// Returns true if the given network state's SSID (or hardware address) is marked for internal
    /// URL use.
    func isOnInternalNetwork(using networkState: NetworkState) -> Bool {
        if let ssid = networkState.ssid, internalSSIDs?.contains(ssid) == true {
            return true
        }

        if let hardwareAddress = networkState.hardwareAddress,
           internalHardwareAddresses?.contains(hardwareAddress) == true {
            return true
        }

        return false
    }

    /// `isOnInternalNetwork(using:)` evaluated against the cached network information, which may be
    /// stale. Only for synchronous evaluation (`evaluateActiveURL()`/`evaluateWebhookURL()`).
    var isOnInternalNetworkUsingLastKnownState: Bool {
        isOnInternalNetwork(using: HANetworkingEnvironment.current.connectivity.lastKnownNetworkState())
    }

    public var hasInternalURLSet: Bool {
        internalURL != nil
    }

    /// Secret as byte array
    public func webhookSecretBytes(version: Version) -> [UInt8]? {
        guard let webhookSecret, webhookSecret.count.isMultiple(of: 2) else {
            return nil
        }

        guard version >= .fullWebhookSecretKey else {
            if let end = webhookSecret.index(
                webhookSecret.startIndex,
                offsetBy: 32,
                limitedBy: webhookSecret.endIndex
            ) {
                return .init(webhookSecret.utf8[webhookSecret.startIndex ..< end])
            } else {
                return nil
            }
        }

        var stringIterator = webhookSecret.makeIterator()

        return Array(AnyIterator<UInt8> {
            guard let first = stringIterator.next(), let second = stringIterator.next() else {
                return nil
            }

            return UInt8(String(first) + String(second), radix: 16)
        })
    }
}

public final class ServerRequestAdapter: RequestAdapter, @unchecked Sendable {
    let server: Server

    public init(server: Server) {
        self.server = server
    }

    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var updatedRequest: URLRequest = urlRequest

        if let currentURL = urlRequest.url {
            // Evaluated against cached network information: every request reaching this adapter
            // just resolved its URL through an async accessor that refreshed the cache moments
            // earlier, so this stays synchronous instead of spawning a Task (and a second network
            // information fetch) per outgoing request.
            if let activeURL = server.info.connection.evaluateActiveURL() {
                let expectedURL = activeURL.adapting(url: currentURL)
                if currentURL != expectedURL {
                    HANetworkingEnvironment.current.log
                        .verbose("Changing request URL from \(currentURL) to \(expectedURL)")
                    updatedRequest.url = expectedURL
                }
            } else {
                HANetworkingEnvironment.current.log
                    .error("ActiveURL was not avaiable when ServerRequestAdapter adapt was called")
                completion(.failure(ServerConnectionError.noActiveURL(server.info.name)))
                return
            }
        }

        completion(.success(updatedRequest))
    }
}
