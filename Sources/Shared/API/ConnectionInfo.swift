import Alamofire
import Foundation
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
    public var activeURLType: URLType {
        if isOnInternalNetwork, internalURL != nil {
            return .internal
        } else if useCloud, remoteUIURL != nil {
            return .remoteUI
        } else {
            return .external
        }
    }

    public var isLocalPushEnabled = true {
        didSet {
            guard oldValue != isLocalPushEnabled else { return }
            Current.Log.verbose("updated local push from \(oldValue) to \(isLocalPushEnabled)")
        }
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
        isLocalPushEnabled: Bool
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
    public var activeURL: URL {
        if let overrideActiveURLType = overrideActiveURLType {
            let overrideURL: URL?

            switch overrideActiveURLType {
            case .internal:
                overrideURL = internalURL
            case .remoteUI:
                overrideURL = remoteUIURL
            case .external:
                overrideURL = externalURL
            }

            if let overrideURL = overrideURL {
                return overrideURL.sanitized()
            }
        }
        
        let url: URL

        if let internalURL = internalURL, isOnInternalNetwork || overrideActiveURLType == .internal {
            url = internalURL
        } else if let remoteUIURL = remoteUIURL, useCloud {
            url = remoteUIURL
        } else if let externalURL = externalURL {
            url = externalURL
        } else {
            url = URL(string: "http://homeassistant.local:8123")!
        }

        return url.sanitized()
    }

    /// Returns the activeURL with /api appended.
    public var activeAPIURL: URL {
        activeURL.appendingPathComponent("api", isDirectory: false)
    }

    public var webhookURL: URL {
        if useCloud, let cloudURL = cloudhookURL {
            return cloudURL
        }

        return activeURL.appendingPathComponent(webhookPath, isDirectory: false)
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
        #if targetEnvironment(simulator)
        return true
        #elseif os(watchOS)
        if let isOnNetwork = Communicator.shared.mostRecentlyReceievedContext.content["isOnInternalNetwork"] as? Bool {
            return isOnNetwork
        }
        return false
        #else
        if let current = Current.connectivity.currentWiFiSSID(),
           internalSSIDs?.contains(current) == true {
            return true
        }

        if let current = Current.connectivity.currentNetworkHardwareAddress(),
           internalHardwareAddresses?.contains(current) == true {
            return true
        }

        return false
        #endif
    }
}

extension ConnectionInfo: RequestAdapter {
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var updatedRequest: URLRequest = urlRequest

        if let currentURL = urlRequest.url {
            let expectedURL = activeURL.adapting(url: currentURL)
            if currentURL != expectedURL {
                Current.Log.verbose("Changing request URL from \(currentURL) to \(expectedURL)")
                updatedRequest.url = expectedURL
            }
        }

        completion(.success(updatedRequest))
    }
}
