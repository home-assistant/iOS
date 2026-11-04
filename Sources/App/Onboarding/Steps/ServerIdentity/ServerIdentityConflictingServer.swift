import Foundation
import Shared

/// A server listed on `ServerIdentityExplanationView` as one of those reporting the same instance ID.
struct ServerIdentityConflictingServer: Hashable, Identifiable {
    let name: String
    let address: String?

    var id: String { "\(name)|\(address ?? "")" }

    init(name: String, address: String?) {
        self.name = name
        self.address = address
    }

    init(info: ServerInfo) {
        let url = info.connection.address(for: .internal) ?? info.connection.address(for: .external)
        self.init(name: info.name, address: url?.sanitized().absoluteString)
    }
}
