import CoreLocation
import Foundation
import Shared

/// Watches the zones of every server the watch shares its location with, and reports the watch's
/// location when it enters or leaves one — the watch's counterpart of the iPhone's `ZoneManager`.
///
/// watchOS has no `CLLocationManager` region monitoring, so this uses `CLMonitor` (watchOS 10+),
/// which keeps monitoring while the app isn't running and relaunches it to deliver events. The
/// conditions persist with the monitor; `rearm()` brings them in line with the zones and the
/// user's choices whenever either changes.
@available(watchOS 10, *)
actor WatchZoneMonitor {
    static let shared = WatchZoneMonitor()

    /// `CLMonitor` allows an app 20 conditions in total.
    static let maximumConditions = 20

    /// Small zones are widened to this radius: below it, geographic conditions are too unreliable
    /// to fire. The report that follows works from a real fix, so a widened zone only decides when
    /// the watch looks, not which zone it says it is in.
    static let minimumRadius: CLLocationDistance = 100

    private static let monitorName = "HomeAssistantWatchZones"

    private var monitor: CLMonitor?
    private var eventsTask: Task<Void, Never>?
    private var zonesObserverTask: Task<Void, Never>?

    /// Opens the monitor and starts handling its events. Run at every launch, including the
    /// background launches `CLMonitor` makes to deliver an event: events are only delivered to a
    /// monitor opened under the same name.
    func start() async {
        guard monitor == nil else { return }
        let monitor = await CLMonitor(Self.monitorName)
        self.monitor = monitor

        eventsTask = Task { [weak self] in
            do {
                for try await event in await monitor.events {
                    await self?.handle(event)
                }
            } catch {
                Current.Log.error("watch zone monitoring stopped: \(error)")
            }
        }

        zonesObserverTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: WatchZoneSync.zonesDidChangeNotification) {
                await self?.rearm()
            }
        }

        await rearm()
    }

    /// Monitors the zones of the servers that receive the watch's location, nearest first when
    /// there are more than `CLMonitor` allows, and stops monitoring everything else.
    func rearm() async {
        guard let monitor else { return }

        let sharing = Current.servers.all.filter {
            WatchUserDefaults.shared.locationPrivacy(forServer: $0.identifier) != .never
        }
        let sharingIDs = Set(sharing.map(\.identifier.rawValue))

        // Zones of servers no longer sharing are of no further use on the watch.
        let staleServerIDs = Set(AppZone.all().map(\.serverIdentifier)).subtracting(sharingIDs)
        for serverID in staleServerIDs {
            WatchZoneSync.removeZones(for: Identifier<Server>(rawValue: serverID))
        }

        let lastLocation = sharing.isEmpty ? nil : await Self.lastKnownLocation()
        let zones = AppZone.trackableZones()
            .filter { sharingIDs.contains($0.serverIdentifier) }
            .sorted { lhs, rhs in
                guard let lastLocation else { return lhs.identifier < rhs.identifier }
                return lastLocation.distance(from: lhs.location) < lastLocation.distance(from: rhs.location)
            }
            .prefix(Self.maximumConditions)
        let desired = Dictionary(zones.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })

        for identifier in await monitor.identifiers where desired[identifier] == nil {
            await monitor.remove(identifier)
        }

        let existing = await Set(monitor.identifiers)
        for (identifier, zone) in desired {
            let condition = CLMonitor.CircularGeographicCondition(
                center: zone.center,
                radius: max(zone.radius, Self.minimumRadius)
            )
            if existing.contains(identifier),
               let record = await monitor.record(for: identifier),
               let current = record.condition as? CLMonitor.CircularGeographicCondition,
               current.center.latitude == condition.center.latitude,
               current.center.longitude == condition.center.longitude,
               current.radius == condition.radius {
                continue
            }
            // Assuming outside means a watch that is already inside reports it once, straight away.
            await monitor.add(condition, identifier: identifier, assuming: .unsatisfied)
        }

        Current.Log.info("watch monitoring \(desired.count) zones")
    }

    private func handle(_ event: CLMonitor.Event) async {
        let entered: Bool
        switch event.state {
        case .satisfied: entered = true
        case .unsatisfied: entered = false
        default: return
        }

        guard let zone = AppZone.zone(identifier: event.identifier) else {
            Current.Log.info("watch zone event for unknown zone \(event.identifier); rearming")
            await rearm()
            return
        }

        Current.Log.info("watch \(entered ? "entered" : "left") \(zone.entityId)")
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Apple Watch \(entered ? "entered" : "exited") \(zone.name)",
            type: .locationUpdate
        ))
        await WatchDeviceReporter.shared.report(
            trigger: .zoneChange,
            zoneEvent: WatchZoneEvent(zone: zone, entered: entered)
        )
    }

    /// `CLLocationManager.location` performs synchronous XPC to locationd, so it's read off the
    /// main thread.
    private static func lastKnownLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: CLLocationManager().location)
            }
        }
    }
}
