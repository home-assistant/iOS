import Alamofire
import Eureka
import Foundation
import HAKit
import PromiseKit
import Shared

enum AccountRowValue: Equatable, CustomStringConvertible {
    case server(Server)
    case add
    case all

    var description: String {
        switch self {
        case let .server(server): return String(describing: server.identifier)
        case .add: return "add"
        case .all: return "all"
        }
    }

    var server: Server? {
        switch self {
        case let .server(server): return server
        case .add: return nil
        case .all: return nil
        }
    }

    var placeholderTitle: String? {
        switch self {
        case .server: return nil
        case .add: return L10n.Settings.ConnectionSection.addServer
        case .all: return L10n.Settings.ConnectionSection.allServers
        }
    }

    func placeholderImage(traitCollection: UITraitCollection) -> UIImage? {
        switch self {
        case .server: return nil
        case .add: return AccountInitialsImage.addImage(traitCollection: traitCollection)
        case .all: return AccountInitialsImage.allImage(traitCollection: traitCollection)
        }
    }
}
