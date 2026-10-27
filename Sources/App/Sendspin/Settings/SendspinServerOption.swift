import Foundation
import Shared

struct SendspinServerOption: Identifiable, Equatable {
    let id: String
    let name: String
    let hasHomeNetwork: Bool

    init(id: String, name: String, hasHomeNetwork: Bool) {
        self.id = id
        self.name = name
        self.hasHomeNetwork = hasHomeNetwork
    }

    init(server: Server) {
        let connection = server.info.connection
        self.init(
            id: server.identifier.rawValue,
            name: server.info.name,
            hasHomeNetwork: !(connection.internalSSIDs ?? []).isEmpty
                || !(connection.internalHardwareAddresses ?? []).isEmpty
        )
    }
}
