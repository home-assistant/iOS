import Foundation

/// `server/state`. An omitted object leaves that role's state unchanged.
struct SendspinServerState: Codable, Equatable {
    let metadata: SendspinMetadataState?
    let controller: SendspinControllerState?
}
