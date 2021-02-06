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
            guard internalSSIDs != oldValue else { return }
            Current.settingsStore.connectionInfo = self
        }
    }

    public var internalHardwareAddresses: [String]? {
        didSet {
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

    public init(
        externalURL: URL?,
        internalURL: URL?,
        cloudhookURL: URL?,
        remoteUIURL: URL?,
        webhookID: String,
        webhookSecret: String?,
        internalSSIDs: [String]?,
        internalHardwareAddresses: [String]?
    ) {
        self.externalURL = externalURL
        self.internalURL = internalURL
        self.cloudhookURL = cloudhookURL
        self.remoteUIURL = remoteUIURL
        self.webhookID = webhookID
        self.webhookSecret = webhookSecret
        self.internalSSIDs = internalSSIDs
        self.internalHardwareAddresses = internalHardwareAddresses

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
    }

    private func sanitize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        if components.path.hasSuffix("/") {
            while components.path.hasSuffix("/") {
                components.path.removeLast()
            }
            return components.url ?? url
        } else {
            return url
        }
    }

    /// Returns the url that should be used at this moment to access the Home Assistant instance.
    public var activeURL: URL {
        switch activeURLType {
        case .internal:
            if let url = internalURL {
                guard isOnInternalNetwork else {
                    if useCloud, canUseCloud {
                        activeURLType = .remoteUI
                    } else if externalURL != nil {
                        activeURLType = .external
                    } else {
                        // no change - we don't have one to switch to
                        return sanitize(url)
                    }
                    return self.activeURL
                }
                return sanitize(url)
            } else {
                // No internal URL available, so fallback to an external URL
                if useCloud, canUseCloud {
                    activeURLType = .remoteUI
                } else {
                    activeURLType = .external
                }
                return self.activeURL
            }
        case .remoteUI:
            if let url = remoteUIURL {
                if let internalURL = self.internalURL, self.isOnInternalNetwork {
                    self.activeURLType = .internal
                    return sanitize(internalURL)
                }
                return sanitize(url)
            } else if externalURL != nil {
                activeURLType = .external
                return self.activeURL
            }
        case .external:
            if useCloud, canUseCloud {
                activeURLType = .remoteUI
                return self.activeURL
            } else if let url = externalURL {
                if let internalURL = self.internalURL, self.isOnInternalNetwork {
                    self.activeURLType = .internal
                    return sanitize(internalURL)
                }
                return sanitize(url)
            }
        }

        let errMsg =
            "Unable to get \(activeURLType), even though its active! Internal URL: \(String(describing: internalURL)), External URL: \(String(describing: externalURL)), Remote UI URL: \(String(describing: remoteUIURL))"
        Current.Log.error(errMsg)

        #if os(iOS)
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "URL Unavailable",
                message: "Expected to have a \(self.activeURLType) but none available! Please enter the URL. App will exit after entry, please reopen.",
                preferredStyle: .alert
            )

            var textField: UITextField?

            alert.addTextField { pTextField in
                pTextField.placeholder = self.activeURLType.description
                pTextField.clearButtonMode = .whileEditing
                pTextField.borderStyle = .none
                textField = pTextField
            }

            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: { _ in
                guard let urlStr = textField?.text, let url = URL(string: urlStr) else { return }
                self.setAddress(url, self.activeURLType)
                exit(1)
            }))
            let win = UIWindow(frame: UIScreen.main.bounds)
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            win.rootViewController = vc
            win.windowLevel = UIWindow.Level.alert + 1
            win.makeKeyAndVisible()
            vc.present(alert, animated: true, completion: nil)
        }

        return URL(string: "http://somethingbroke.fake")!
        #else
        fatalError(errMsg)
        #endif
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
