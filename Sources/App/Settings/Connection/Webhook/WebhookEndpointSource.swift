import Foundation
import Shared

/// Where a webhook URL comes from.
///
/// Only Home Assistant Cloud subscribers get a `cloudhook`; without one the app builds the webhook
/// URL out of the server's own URLs, which is why all of them are listed as possible sources.
enum WebhookEndpointSource: Hashable {
    case cloudhook
    case internalURL
    case remoteUI
    case externalURL

    var title: String {
        switch self {
        case .cloudhook:
            return L10n.Settings.ConnectionSection.Cloudhook.title
        case .internalURL:
            return L10n.Settings.ConnectionSection.InternalBaseUrl.title
        case .remoteUI:
            return L10n.Settings.ConnectionSection.RemoteUiUrl.title
        case .externalURL:
            return L10n.Settings.ConnectionSection.ExternalBaseUrl.title
        }
    }
}
