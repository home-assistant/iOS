import Foundation

/// A service to call and what to call it on. The home dashboard only ever targets a whole area or a
/// single entity, so those are the only two targets here.
public struct HomeServiceCall: Equatable, Hashable, Sendable {
    /// The service in `domain.service` form, e.g. `"light.turn_on"`.
    public let service: String
    public let areaId: String?
    public let entityId: String?

    public init(service: String, areaId: String? = nil, entityId: String? = nil) {
        self.service = service
        self.areaId = areaId
        self.entityId = entityId
    }
}
