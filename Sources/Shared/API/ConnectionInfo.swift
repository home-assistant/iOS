import Alamofire
import Foundation
#if os(watchOS)
import Communicator
#endif

public class ConnectionInfo: Codable {
    public private(set) var externalURL: URL? {
        didSet {
            guard externalURL != oldValue else { return }
            Current.settingsStore.connectionInfo = self
            guard externalURL != nil else { return }
            Current.crashReporter.setUserProperty(value: "externalURL", name: "RemoteConnectionMethod")
        }
    }

    public private(set) var internalURL: URL? {
        didSet {
            guard internalURL != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public private(set) var remoteUIURL: URL? {
        didSet {
            guard remoteUIURL != oldValue else { return }
            Current.settingsStore.connectionInfo = self
            guard remoteUIURL != nil else { return }
            Current.crashReporter.setUserProperty(value: "remoteUI", name: "RemoteConnectionMethod")
        }
    }

    public var webhookID: String {
        didSet {
            guard webhookID != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public var webhookSecret: String? {
        didSet {
            guard webhookSecret != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public var cloudhookURL: URL? {
        didSet {
            guard cloudhookURL != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public var internalSSIDs: [String]? {
        didSet {
            overrideActiveURLType = nil
            guard internalSSIDs != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public var internalHardwareAddresses: [String]? {
        didSet {
            overrideActiveURLType = nil
            guard internalHardwareAddresses != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public var canUseCloud: Bool {
        remoteUIURL != nil
    }

    public var useCloud: Bool = false {
        didSet {
            guard useCloud != oldValue else { return }

            Current.settingsStore.connectionInfo = self
            if useCloud {
                if internalURL != nil, isOnInternalNetwork {
                    activeURLType = .internal
                } else {
                    activeURLType = .remoteUI
                }
            } else {
                if internalURL != nil, isOnInternalNetwork {
                    activeURLType = .internal
                } else {
                    activeURLType = .external
                }
            }
        }
    }

    public var overrideActiveURLType: URLType?

    public var activeURLType: URLType = .external {
        didSet {
            guard oldValue != activeURLType else { return }
            var oldURL: String = "Unknown URL"
            switch oldValue {
            case .internal:
                oldURL = internalURL?.absoluteString ?? oldURL
            case .remoteUI:
                oldURL = remoteUIURL?.absoluteString ?? oldURL
            case .external:
                oldURL = externalURL?.absoluteString ?? oldURL
            }
            Current.Log.verbose("Updated URL from \(oldValue) (\(oldURL)) to \(activeURLType) \(activeURL)")
            Current.settingsStore.connectionInfo = self
        }
    }

    public var isLocalPushEnabled = true {
        didSet {
            guard oldValue != isLocalPushEnabled else { return }
            Current.Log.verbose("updated local push from \(oldValue) to \(isLocalPushEnabled)")
            Current.settingsStore.connectionInfo = self
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

        if self.internalURL != nil, self.internalSSIDs != nil, isOnInternalNetwork {
            self.activeURLType = .internal
        } else {
            if useCloud, canUseCloud {
                self.activeURLType = .remoteUI
            } else {
                self.activeURLType = .external
            }
        }
    }

    // https://stackoverflow.com/a/53237340/486182
    public required init(from decoder: Decoder) throws {
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
        self.activeURLType = try container.decode(URLType.self, forKey: .activeURLType)
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
            activeURLType = .internal
            url = internalURL
        } else if let remoteUIURL = remoteUIURL, useCloud {
            activeURLType = .remoteUI
            url = remoteUIURL
        } else if let externalURL = externalURL {
            activeURLType = .external
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

    /// Updates the stored address for the given addressType.
    // swiftlint:disable:next cyclomatic_complexity
    public func setAddress(_ address: URL?, _ addressType: URLType) {
        switch addressType {
        case .internal:
            internalURL = address
            if internalURL == nil {
                if useCloud, canUseCloud {
                    activeURLType = .remoteUI
                } else {
                    activeURLType = .external
                }
            } else if internalURL != nil, isOnInternalNetwork {
                activeURLType = .internal
            }
        case .external:
            externalURL = address
            if externalURL == nil {
                if internalURL != nil, isOnInternalNetwork {
                    activeURLType = .internal
                } else if useCloud, canUseCloud {
                    activeURLType = .remoteUI
                }
            } else if activeURLType != .internal {
                activeURLType = .external
            }
        case .remoteUI:
            remoteUIURL = address
            if remoteUIURL == nil {
                if internalURL != nil, isOnInternalNetwork {
                    activeURLType = .internal
                } else if externalURL != nil {
                    activeURLType = .external
                }
            } else if activeURLType != .internal, useCloud {
                activeURLType = .remoteUI
            }
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

    /// Returns the URLType of the given URL, if it is known.
    public func getURLType(_ url: URL) -> URLType? {
        if url.scheme == internalURL?.scheme, url.host == internalURL?.host,
           url.port == internalURL?.port {
            return .internal
        } else if url.scheme == externalURL?.scheme, url.host == externalURL?.host,
                  url.port == externalURL?.port {
            return .external
        } else if url.scheme == remoteUIURL?.scheme, url.host == remoteUIURL?.host,
                  url.port == remoteUIURL?.port {
            return .remoteUI
        }

        return nil
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
