import CoreLocation
import Foundation
import HAKit
import RealmSwift

private extension HAEntityAttributes {
    // app-specific attributes for zones, always optional
    var isTrackingEnabled: Bool { self["track_ios"] as? Bool ?? true }
    var beaconUUID: String? { beacon["uuid"] as? String }
    var beaconMajor: Int? { beacon["major"] as? Int }
    var beaconMinor: Int? { beacon["minor"] as? Int }
    var ssidTrigger: [String] { self["ssid_trigger"] as? [String] ?? [] }
    var ssidFilter: [String] { self["ssid_filter"] as? [String] ?? [] }

    private var beacon: [String: Any] { self["beacon"] as? [String: Any] ?? [:] }
}

public final class RLMZone: Object, UpdatableModel {
    @objc public dynamic var identifier: String = ""
    @objc public dynamic var entityId: String = "" {
        didSet {
            identifier = Self.primaryKey(sourceIdentifier: entityId, serverIdentifier: serverIdentifier)
        }
    }

    @objc public dynamic var serverIdentifier: String = "" {
        didSet {
            identifier = Self.primaryKey(sourceIdentifier: entityId, serverIdentifier: serverIdentifier)
        }
    }

    @objc public dynamic var FriendlyName: String?
    @objc public dynamic var Latitude: Double = 0.0
    @objc public dynamic var Longitude: Double = 0.0
    @objc public dynamic var Radius: Double = 0.0
    @objc public dynamic var TrackingEnabled = true
    @objc public dynamic var enterNotification = true
    @objc public dynamic var exitNotification = true
    @objc public dynamic var inRegion = false
    @objc public dynamic var isPassive = false

    // Beacons
    @objc public dynamic var BeaconUUID: String?
    public let BeaconMajor = RealmProperty<Int?>()
    public let BeaconMinor = RealmProperty<Int?>()

    // SSID
    public var SSIDTrigger = List<String>()
    public var SSIDFilter = List<String>()

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    public var isHome: Bool {
        entityId == "zone.home"
    }

    static func didUpdate(objects: [RLMZone], server: Server, realm: Realm) {}

    static func willDelete(objects: [RLMZone], server: Server?, realm: Realm) {}

    func update(with zone: HAEntity, server: Server, using: Realm) -> Bool {
        guard let zoneAttributes = zone.attributes.zone else {
            return false
        }

        if realm == nil {
            entityId = zone.entityId
        } else {
            precondition(zone.entityId == entityId)
        }

        serverIdentifier = server.identifier.rawValue
        FriendlyName = zone.attributes.friendlyName
        Latitude = zoneAttributes.latitude
        Longitude = zoneAttributes.longitude
        Radius = zoneAttributes.radius.converted(to: .meters).value
        isPassive = zoneAttributes.isPassive

        // app-specific attributes
        TrackingEnabled = zone.attributes.isTrackingEnabled
        BeaconUUID = zone.attributes.beaconUUID
        BeaconMajor.value = zone.attributes.beaconMajor
        BeaconMinor.value = zone.attributes.beaconMinor

        SSIDTrigger.removeAll()
        SSIDTrigger.append(objectsIn: zone.attributes.ssidTrigger)
        SSIDFilter.removeAll()
        SSIDFilter.append(objectsIn: zone.attributes.ssidFilter)

        return true
    }

    public static var trackablePredicate: NSPredicate {
        .init(format: "TrackingEnabled == true && isPassive == false")
    }

    public var center: CLLocationCoordinate2D {
        .init(
            latitude: Latitude,
            longitude: Longitude
        )
    }

    public var location: CLLocation {
        CLLocation(
            coordinate: center,
            altitude: 0,
            horizontalAccuracy: Radius,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }

    public var regionsForMonitoring: [CLRegion] {
        #if os(iOS)
        if let beaconRegion = beaconRegion {
            return [beaconRegion]
        } else {
            return circularRegionsForMonitoring
        }
        #else
        return circularRegionsForMonitoring
        #endif
    }

    public var circularRegion: CLCircularRegion {
        let region = CLCircularRegion(center: center, radius: Radius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    #if os(iOS)
    public var beaconRegion: CLBeaconRegion? {
        guard let uuidString = BeaconUUID else {
            return nil
        }

        guard let uuid = UUID(uuidString: uuidString) else {
            let event =
                ClientEvent(
                    text: "Unable to create beacon region due to invalid UUID: \(uuidString)",
                    type: .locationUpdate
                )
            Current.clientEventStore.addEvent(event).cauterize()
            return nil
        }

        let beaconRegion: CLBeaconRegion

        if let major = BeaconMajor.value, let minor = BeaconMinor.value {
            if #available(iOS 13, *) {
                beaconRegion = CLBeaconRegion(
                    uuid: uuid,
                    major: CLBeaconMajorValue(major),
                    minor: CLBeaconMinorValue(minor),
                    identifier: identifier
                )
            } else {
                beaconRegion = CLBeaconRegion(
                    proximityUUID: uuid,
                    major: CLBeaconMajorValue(major),
                    minor: CLBeaconMinorValue(minor),
                    identifier: identifier
                )
            }
        } else if let major = BeaconMajor.value {
            if #available(iOS 13, *) {
                beaconRegion = CLBeaconRegion(
                    uuid: uuid,
                    major: CLBeaconMajorValue(major),
                    identifier: identifier
                )
            } else {
                beaconRegion = CLBeaconRegion(
                    proximityUUID: uuid,
                    major: CLBeaconMajorValue(major),
                    identifier: identifier
                )
            }
        } else {
            if #available(iOS 13, *) {
                beaconRegion = CLBeaconRegion(uuid: uuid, identifier: identifier)
            } else {
                beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: identifier)
            }
        }

        beaconRegion.notifyEntryStateOnDisplay = true
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
        return beaconRegion
    }
    #endif

    public func containsInRegions(_ location: CLLocation) -> Bool {
        circularRegionsForMonitoring.allSatisfy { $0.containsWithAccuracy(location) }
    }

    public var circularRegionsForMonitoring: [CLCircularRegion] {
        if Radius >= 100 {
            // zone is big enough to not have false-enters
            let region = CLCircularRegion(center: center, radius: Radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            return [region]
        } else {
            // zone is too small for region monitoring without false-enters
            // see https://github.com/home-assistant/iOS/issues/784

            // given we're a circle centered at (lat, long) with radius R
            // and we want to be a series of circles with radius 100m that overlap our circle as best as possible
            let numberOfCircles = 3
            let minimumRadius: Double = 100.0
            let centerOffset = Measurement<UnitLength>(value: minimumRadius - Radius, unit: .meters)
            let sliceAngle = ((2.0 * Double.pi) / Double(numberOfCircles))

            let angles: [Measurement<UnitAngle>] = (0 ..< numberOfCircles).map { amount in
                .init(value: sliceAngle * Double(amount), unit: .radians)
            }

            return angles.map { angle in
                CLCircularRegion(
                    center: center.moving(distance: centerOffset, direction: angle),
                    radius: minimumRadius,
                    identifier: String(format: "%@@%03.0f", identifier, angle.converted(to: .degrees).value)
                )
            }
        }
    }

    override public static func primaryKey() -> String? {
        #keyPath(identifier)
    }

    static func serverIdentifierKey() -> String {
        #keyPath(serverIdentifier)
    }

    public var Name: String {
        if isInvalidated { return "Deleted" }
        if let fName = FriendlyName { return fName }
        return entityId.replacingOccurrences(
            of: "\(Domain).",
            with: ""
        ).replacingOccurrences(
            of: "_",
            with: " "
        ).capitalized
    }

    public var deviceTrackerName: String {
        entityId.replacingOccurrences(of: "\(Domain).", with: "")
    }

    public var Domain: String {
        "zone"
    }

    public var isBeaconRegion: Bool {
        if self.isInvalidated { return false }
        return self.BeaconUUID != nil
    }

    override public var debugDescription: String {
        "Zone - ID: \(identifier), state: " + (inRegion ? "inside" : "outside")
    }

    public static func zone(of location: CLLocation, in server: Server) -> Self? {
        Current.realm()
            .objects(Self.self)
            .filter("%K == %@", #keyPath(serverIdentifier), server.identifier.rawValue)
            .filter(trackablePredicate)
            .filter { $0.circularRegion.containsWithAccuracy(location) }
            .sorted { zoneA, zoneB in
                // match the smaller zone over the larger
                zoneA.Radius < zoneB.Radius
            }
            .first
    }
}
