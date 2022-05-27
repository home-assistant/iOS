import Alamofire
import Foundation
import Version
#if os(watchOS)
import Communicator
#endif

public struct ConnectionInfo: Codable, Equatable {
    private var externalURL: URL?
    private var internalURL: URL?
    private var remoteUIURL: URL?
    public var webhookID: String
    public var webhookSecret: String?
    public var useCloud: Bool = false
    public var cloudhookURL: URL?
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

    public var overrideActiveURLType: URLType?
    public private(set) var activeURLType: URLType = .internal

    public var isLocalPushEnabled = true {
        didSet {
            guard oldValue != isLocalPushEnabled else { return }
            Current.Log.verbose("updated local push from \(oldValue) to \(isLocalPushEnabled)")
        }
    }

    public var securityExceptions: SecurityExceptions = .init()
    public func evaluate(_ challenge: URLAuthenticationChallenge)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
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
        securityExceptions: SecurityExceptions
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

        public var debugDescription: String {
            switch self {
            case .internal:
                return "Internal URL"
            case .remoteUI:
                return "Remote UI"
            case .external:
                return "External URL"
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
            }
        }

        public var isAffectedBySSID: Bool {
            switch self {
            case .internal: return true
            case .remoteUI, .external: return false
            }
        }

        public var isAffectedByCloud: Bool {
            switch self {
            case .internal: return false
            case .remoteUI, .external: return true
            }
        }

        public var isAffectedByHardwareAddress: Bool {
            switch self {
            case .internal: return Current.isCatalyst
            case .remoteUI, .external: return false
            }
        }

        public var hasLocalPush: Bool {
            switch self {
            case .internal:
                if Current.isCatalyst {
                    return false
                }
                if #available(iOS 14, *) {
                    return true
                } else {
                    return false
                }
            default: return false
            }
        }
    }

    /// Returns the url that should be used at this moment to access the Home Assistant instance.
    public mutating func activeURL() -> URL {
        if let overrideActiveURLType = overrideActiveURLType {
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
            }

            if let overrideURL = overrideURL {
                return overrideURL.sanitized()
            }
        }

        let url: URL

        if let internalURL = internalURL, isOnInternalNetwork || overrideActiveURLType == .internal {
            activeURLType = .internal
            url = internalURL
        } else if let remoteUIURL = remoteUIURL, useCloud {
            activeURLType = .remoteUI
            url = remoteUIURL
        } else if let externalURL = externalURL {
            activeURLType = .external
            url = externalURL
        } else {
            // we're missing a url, so try and fall back to one that _could_ work
            if let remoteUIURL = remoteUIURL {
                activeURLType = .remoteUI
                url = remoteUIURL
            } else if let internalURL = internalURL {
                activeURLType = .internal
                url = internalURL
            } else {
                activeURLType = .internal
                url = URL(string: "http://homeassistant.local:8123")!
            }
        }

        return url.sanitized()
    }

    /// Returns the activeURL with /api appended.
    public mutating func activeAPIURL() -> URL {
        activeURL().appendingPathComponent("api", isDirectory: false)
    }

    public mutating func webhookURL() -> URL {
        if let cloudhookURL = cloudhookURL, !isOnInternalNetwork {
            return cloudhookURL
        }

        return activeURL().appendingPathComponent(webhookPath, isDirectory: false)
    }

    public var webhookPath: String {
        "api/webhook/\(webhookID)"
    }

    public func address(for addressType: URLType) -> URL? {
        switch addressType {
        case .internal: return internalURL
        case .external: return externalURL
        case .remoteUI: return remoteUIURL
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

    /// Secret as byte array
    func webhookSecretBytes(version: Version) -> [UInt8]? {
        guard let webhookSecret = webhookSecret, webhookSecret.count.isMultiple(of: 2) else {
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
            let expectedURL = server.info.connection.activeURL().adapting(url: currentURL)
            if currentURL != expectedURL {
                Current.Log.verbose("Changing request URL from \(currentURL) to \(expectedURL)")
                updatedRequest.url = expectedURL
            }
        }

        completion(.success(updatedRequest))
    }
}
