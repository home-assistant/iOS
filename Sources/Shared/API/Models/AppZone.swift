import CoreLocation
import Foundation
import GRDB
import HAKit

public struct AppZone: Codable, FetchableRecord, PersistableRecord {
    /// serverId/entityId (e.g., "server1/zone.home")
    public let id: String
    public let serverId: String
    public let entityId: String
    public var friendlyName: String?
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var trackingEnabled: Bool
    public var enterNotification: Bool
    public var exitNotification: Bool
    public var inRegion: Bool
    public var isPassive: Bool
    
    // Beacons
    public var beaconUUID: String?
    public var beaconMajor: Int?
    public var beaconMinor: Int?
    
    // SSID
    public var ssidTrigger: [String]
    public var ssidFilter: [String]
    
    public init(
        id: String,
        serverId: String,
        entityId: String,
        friendlyName: String?,
        latitude: Double,
        longitude: Double,
        radius: Double,
        trackingEnabled: Bool,
        enterNotification: Bool,
        exitNotification: Bool,
        inRegion: Bool,
        isPassive: Bool,
        beaconUUID: String?,
        beaconMajor: Int?,
        beaconMinor: Int?,
        ssidTrigger: [String],
        ssidFilter: [String]
    ) {
        self.id = id
        self.serverId = serverId
        self.entityId = entityId
        self.friendlyName = friendlyName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.trackingEnabled = trackingEnabled
        self.enterNotification = enterNotification
        self.exitNotification = exitNotification
        self.inRegion = inRegion
        self.isPassive = isPassive
        self.beaconUUID = beaconUUID
        self.beaconMajor = beaconMajor
        self.beaconMinor = beaconMinor
        self.ssidTrigger = ssidTrigger
        self.ssidFilter = ssidFilter
    }
    
    public static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }
    
    public var isHome: Bool {
        entityId == "zone.home"
    }
    
    public var center: CLLocationCoordinate2D {
        .init(
            latitude: latitude,
            longitude: longitude
        )
    }
    
    public var location: CLLocation {
        CLLocation(
            coordinate: center,
            altitude: 0,
            horizontalAccuracy: radius,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }
    
    public var regionsForMonitoring: [CLRegion] {
        #if os(iOS)
        if let beaconRegion {
            return [beaconRegion]
        } else {
            return circularRegionsForMonitoring
        }
        #else
        return circularRegionsForMonitoring
        #endif
    }
    
    public var circularRegion: CLCircularRegion {
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
    
    #if os(iOS)
    public var beaconRegion: CLBeaconRegion? {
        guard let uuidString = beaconUUID else {
            return nil
        }
        
        guard let uuid = UUID(uuidString: uuidString) else {
            let event =
                ClientEvent(
                    text: "Unable to create beacon region due to invalid UUID: \(uuidString)",
                    type: .locationUpdate
                )
            Current.clientEventStore.addEvent(event)
            return nil
        }
        
        let beaconRegion: CLBeaconRegion
        
        if let major = beaconMajor, let minor = beaconMinor {
            beaconRegion = CLBeaconRegion(
                uuid: uuid,
                major: CLBeaconMajorValue(major),
                minor: CLBeaconMinorValue(minor),
                identifier: id
            )
        } else if let major = beaconMajor {
            beaconRegion = CLBeaconRegion(
                uuid: uuid,
                major: CLBeaconMajorValue(major),
                identifier: id
            )
        } else {
            beaconRegion = CLBeaconRegion(uuid: uuid, identifier: id)
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
        if radius >= 100 {
            // zone is big enough to not have false-enters
            let region = CLCircularRegion(center: center, radius: radius, identifier: id)
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
            let centerOffset = Measurement<UnitLength>(value: minimumRadius - radius, unit: .meters)
            let sliceAngle = ((2.0 * Double.pi) / Double(numberOfCircles))
            
            let angles: [Measurement<UnitAngle>] = (0 ..< numberOfCircles).map { amount in
                .init(value: sliceAngle * Double(amount), unit: .radians)
            }
            
            return angles.map { angle in
                CLCircularRegion(
                    center: center.moving(distance: centerOffset, direction: angle),
                    radius: minimumRadius,
                    identifier: String(format: "%@@%03.0f", id, angle.converted(to: .degrees).value)
                )
            }
        }
    }
    
    public var name: String {
        if let fName = friendlyName { return fName }
        return entityId.replacingOccurrences(
            of: "zone.",
            with: ""
        ).replacingOccurrences(
            of: "_",
            with: " "
        ).capitalized
    }
    
    public var deviceTrackerName: String {
        entityId.replacingOccurrences(of: "zone.", with: "")
    }
    
    public var isBeaconRegion: Bool {
        beaconUUID != nil
    }
}

extension AppZone {
    public init(from zone: HAEntity, server: Server) {
        guard let zoneAttributes = zone.attributes.zone else {
            fatalError("Invalid zone entity")
        }
        
        let identifier = Self.primaryKey(sourceIdentifier: zone.entityId, serverIdentifier: server.identifier.rawValue)
        
        self.init(
            id: identifier,
            serverId: server.identifier.rawValue,
            entityId: zone.entityId,
            friendlyName: zone.attributes.friendlyName,
            latitude: zoneAttributes.latitude,
            longitude: zoneAttributes.longitude,
            radius: zoneAttributes.radius.converted(to: .meters).value,
            trackingEnabled: zone.attributes.isTrackingEnabled,
            enterNotification: true,
            exitNotification: true,
            inRegion: false,
            isPassive: zoneAttributes.isPassive,
            beaconUUID: zone.attributes.beaconUUID,
            beaconMajor: zone.attributes.beaconMajor,
            beaconMinor: zone.attributes.beaconMinor,
            ssidTrigger: zone.attributes.ssidTrigger,
            ssidFilter: zone.attributes.ssidFilter
        )
    }
}

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
