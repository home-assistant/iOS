import Foundation
import HANetworking

// Localized display strings for HANetworking types. They live here in the Shared module because the
// HANetworking package cannot reach `L10n` (the localization resources stay in Shared). The types are
// L10n-free in the package; these extensions add the user-facing text.

public extension ConnectionSecurityLevel {
    var description: String {
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

extension ConnectionInfo.URLType: @retroactive CustomStringConvertible {
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
}

public extension ServerLocationPrivacy {
    var localizedDescription: String {
        switch self {
        case .never: return L10n.Settings.ConnectionSection.LocationSendType.Setting.never
        case .exact: return L10n.Settings.ConnectionSection.LocationSendType.Setting.exact
        case .zoneOnly: return L10n.Settings.ConnectionSection.LocationSendType.Setting.zoneOnly
        }
    }
}

public extension ServerSensorPrivacy {
    var localizedDescription: String {
        switch self {
        case .all: return L10n.Settings.ConnectionSection.SensorSendType.Setting.all
        case .none: return L10n.Settings.ConnectionSection.SensorSendType.Setting.none
        }
    }
}

public extension ServerInfo {
    static var defaultName: String {
        L10n.Settings.StatusSection.LocationNameRow.placeholder
    }
}

extension TokenManager.TokenError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .tokenUnavailable:
            return L10n.TokenError.tokenUnavailable
        case .expired:
            return L10n.TokenError.expired
        case .connectionFailed:
            return L10n.TokenError.connectionFailed
        }
    }
}

extension ServerConnectionError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .noActiveURL(serverName):
            return L10n.Network.Error.NoActiveUrl.description(serverName)
        }
    }
}

public extension Error {
    /// True when this is `ServerConnectionError.noActiveURL`. Exposed from Shared because
    /// HANetworking is linked only through Shared, so consumers (the watch app) can't import the
    /// package to pattern-match the error themselves.
    var isNoActiveURLError: Bool {
        guard let error = self as? ServerConnectionError, case .noActiveURL = error else { return false }
        return true
    }
}
