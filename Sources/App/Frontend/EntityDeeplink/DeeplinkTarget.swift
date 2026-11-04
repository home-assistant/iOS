import Foundation
import Shared

enum DeeplinkTarget: Equatable {
    case entity(id: String)
    case page(path: String)

    private static let externalAuthQueryItem = "external_auth"

    static func page(from url: URL) -> DeeplinkTarget? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = components.queryItems?.filter { $0.name != externalAuthQueryItem }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }

        var path = components.percentEncodedPath
        if path.hasPrefix("/") { path.removeFirst() }
        if let query = components.percentEncodedQuery {
            path += "?\(query)"
        }
        return .page(path: path)
    }

    var localizedDescription: String {
        switch self {
        case .entity:
            L10n.Deeplink.description
        case .page:
            L10n.Deeplink.Page.description
        }
    }

    func url(serverName: String?) -> URL? {
        switch (self, serverName) {
        case let (.entity(id), .some(serverName)):
            AppConstants.openEntityMoreInfoDeeplinkURL(entityId: id, serverName: serverName)
        case let (.entity(id), .none):
            AppConstants.openEntityMoreInfoDeeplinkURL(entityId: id)
        case let (.page(path), .some(serverName)):
            AppConstants.pageDeeplinkURL(path: path, serverName: serverName)
        case let (.page(path), .none):
            AppConstants.pageDeeplinkURL(path: path)
        }
    }
}
