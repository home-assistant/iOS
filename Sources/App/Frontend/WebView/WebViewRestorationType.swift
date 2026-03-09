import Foundation
import Shared

enum WebViewRestorationType {
    case userActivity(NSUserActivity)
    case coder(NSCoder)
    case server(Server)

    init?(_ userActivity: NSUserActivity?) {
        if let userActivity {
            self = .userActivity(userActivity)
        } else {
            return nil
        }
    }

    var initialURL: URL? {
        switch self {
        case let .userActivity(userActivity):
            return userActivity.userInfo?[RestorableStateKey.lastURL.rawValue] as? URL
        case let .coder(coder):
            return coder.decodeObject(of: NSURL.self, forKey: RestorableStateKey.lastURL.rawValue) as URL?
        case .server:
            return nil
        }
    }

    var server: Server? {
        let serverRawValue: String?

        switch self {
        case let .userActivity(userActivity):
            serverRawValue = userActivity.userInfo?[RestorableStateKey.server.rawValue] as? String
        case let .coder(coder):
            serverRawValue = coder.decodeObject(
                of: NSString.self,
                forKey: RestorableStateKey.server.rawValue
            ) as String?
        case let .server(server):
            return server
        }

        return Current.servers.server(forServerIdentifier: serverRawValue)
    }
}
