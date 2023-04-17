import Foundation
import Shared

public extension ServerManager {
    func isConnected() -> Bool {
        return all.contains(where: { isConnected(server: $0) })
    }
    
    func isConnected(server: Server) -> Bool{
        switch Current.api(for: server).connection.state {
        case .ready(version: _):
            return true
        default:
            return false
        }
    }
    
    func getServer(id: Identifier<Server>? = nil) -> Server? {
        guard let id = id else {
            return all.first(where: {isConnected(server: $0)} )
        }
        return server(for: id)
    }
}
