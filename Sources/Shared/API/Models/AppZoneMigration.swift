import Foundation
import GRDB
import RealmSwift

public enum AppZoneMigration {
    /// Migrate zones from Realm to GRDB
    /// This is a one-time migration that copies all existing zones from Realm to GRDB
    public static func migrateFromRealm() {
        let userDefaultsKey = "AppZoneMigration.hasCompleted"

        guard !UserDefaults.standard.bool(forKey: userDefaultsKey) else {
            Current.Log.verbose("Zone migration from Realm to GRDB already completed")
            return
        }

        Current.Log.info("Starting zone migration from Realm to GRDB")

        do {
            let realm = Current.realm()
            let realmZones = Array(realm.objects(RLMZone.self))

            guard !realmZones.isEmpty else {
                Current.Log.info("No zones found in Realm to migrate")
                UserDefaults.standard.set(true, forKey: userDefaultsKey)
                return
            }

            var migratedZones: [AppZone] = []
            for realmZone in realmZones {
                let appZone = AppZone(
                    id: realmZone.identifier,
                    serverId: realmZone.serverIdentifier,
                    entityId: realmZone.entityId,
                    friendlyName: realmZone.FriendlyName,
                    latitude: realmZone.Latitude,
                    longitude: realmZone.Longitude,
                    radius: realmZone.Radius,
                    trackingEnabled: realmZone.TrackingEnabled,
                    enterNotification: realmZone.enterNotification,
                    exitNotification: realmZone.exitNotification,
                    inRegion: realmZone.inRegion,
                    isPassive: realmZone.isPassive,
                    beaconUUID: realmZone.BeaconUUID,
                    beaconMajor: realmZone.BeaconMajor.value,
                    beaconMinor: realmZone.BeaconMinor.value,
                    ssidTrigger: Array(realmZone.SSIDTrigger),
                    ssidFilter: Array(realmZone.SSIDFilter)
                )
                migratedZones.append(appZone)
            }

            try AppZone.save(migratedZones)

            UserDefaults.standard.set(true, forKey: userDefaultsKey)

            Current.Log.info("Successfully migrated \(migratedZones.count) zones from Realm to GRDB")
            Current.clientEventStore.addEvent(.init(
                text: "Migrated \(migratedZones.count) zones from Realm to GRDB",
                type: .database
            ))
        } catch {
            Current.Log.error("Failed to migrate zones from Realm to GRDB: \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to migrate zones from Realm to GRDB",
                type: .database,
                payload: [
                    "error": error.localizedDescription,
                ]
            ))
        }
    }
}
