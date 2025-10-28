import Alamofire
import Foundation
import Version
#if os(watchOS)
import Communicator
#endif

public enum ConnectionSecurityLevel: String, Codable {
    // User has not opted in or out of security checks
    case undefined
    // Checks for home network before connecting to non-https URLs
    case mostSecure
    // Allows non-https URLs always
    case lessSecure

    public var description: String {
        switch self {
        case .undefined:
            return L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.Undefined.title
        case .mostSecure:
            return L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.MostSecure.title
        case .lessSecure:
            return L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.LessSecure.title
        }
    }
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

    public var hasNonHTTPSURLOption: Bool {
        let https = "https"
        if let externalURL, externalURL.scheme?.lowercased() != https {
            return true
        }

        if let internalURL, internalURL.scheme?.lowercased() != https {
            return true
        }

        if let remoteUIURL, remoteUIURL.scheme?.lowercased() != https {
            return true
        }

        return false
    }

    public var overrideActiveURLType: URLType?
    public private(set) var activeURLType: URLType = .external

    public var isLocalPushEnabled = true {
        didSet {
            guard oldValue != isLocalPushEnabled else { return }
            Current.Log.verbose("updated local push from \(oldValue) to \(isLocalPushEnabled)")
        }
    }

    public var securityExceptions: SecurityExceptions = .init()
    public func evaluate(_ challenge: URLAuthenticationChallenge)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        securityExceptions.evaluate(challenge)
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
        connectionAccessSecurityLevel: ConnectionSecurityLevel
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
    }

    public enum URLType: Int, Codable, CaseIterable, CustomStringConvertible, CustomDebugStringConvertible {
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

        public var description: String {
            switch self {
            case .internal:
                return L10n.Settings.ConnectionSection.InternalBaseUrl.title
            case .remoteUI:
                return L10n.Settings.ConnectionSection.RemoteUiUrl.title
            case .external:
                return L10n.Settings.ConnectionSection.ExternalBaseUrl.title
            case .none:
                return L10n.Settings.ConnectionSection.NoBaseUrl.title
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
            case .internal: return Current.isCatalyst
            case .remoteUI, .external, .none: return false
            }
        }

        public var hasLocalPush: Bool {
            switch self {
            case .internal:
                if Current.isCatalyst {
                    return false
                }
                return true
            default: return false
            }
        }
    }

    /// Returns the url that should be used at this moment to access the Home Assistant instance.
    public mutating func activeURL() -> URL? {
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

        if let internalURL, isOnInternalNetwork || overrideActiveURLType == .internal {
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

    /// Returns the activeURL with /api appended.
    public mutating func activeAPIURL() -> URL? {
        if let activeURL = activeURL() {
            return activeURL.appendingPathComponent("api", isDirectory: false)
        } else {
            return nil
        }
    }

    public mutating func webhookURL() -> URL? {
        if let cloudhookURL, !isOnInternalNetwork {
            return cloudhookURL
        }

        if let activeURL = activeURL() {
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

    /// Returns true if current SSID is SSID marked for internal URL use.
    public var isOnInternalNetwork: Bool {
        if let current = Current.connectivity.currentWiFiSSID(),
           internalSSIDs?.contains(current) == true {
            return true
        }

        if let current = Current.connectivity.currentNetworkHardwareAddress(),
           internalHardwareAddresses?.contains(current) == true {
            return true
        }

        return false
    }

    public var hasInternalURLSet: Bool {
        internalURL != nil
    }

    /// Secret as byte array
    func webhookSecretBytes(version: Version) -> [UInt8]? {
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

class ServerRequestAdapter: RequestAdapter {
    let server: Server

    init(server: Server) {
        self.server = server
    }

    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var updatedRequest: URLRequest = urlRequest

        if let currentURL = urlRequest.url {
            if let activeURL = server.info.connection.activeURL() {
                let expectedURL = activeURL.adapting(url: currentURL)
                if currentURL != expectedURL {
                    Current.Log.verbose("Changing request URL from \(currentURL) to \(expectedURL)")
                    updatedRequest.url = expectedURL
                }
            } else {
                Current.Log.error("ActiveURL was not avaiable when ServerRequestAdapter adapt was called")
                completion(.failure(ServerConnectionError.noActiveURL(server.info.name)))
            }
        }

        completion(.success(updatedRequest))
    }
}
