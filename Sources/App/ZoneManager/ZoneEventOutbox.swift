import Foundation

protocol ZoneEventOutbox: AnyObject {
    func pendingEvents() throws -> [PendingZoneEvent]
    func append(_ event: PendingZoneEvent) throws
    func markDeliveryStarted(id: UUID, at date: Date) throws
    func clearDeliveryStarted(id: UUID) throws
    func remove(id: UUID) throws
}
