import Foundation
import Shared

public extension ServerManager {
    func getServer(id: Identifier<Server>? = nil) -> Server? {
        guard let id = id else {
            return all.first
        }
        return server(for: id)
    }
}
