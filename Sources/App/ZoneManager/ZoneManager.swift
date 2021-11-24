import CoreLocation
import Foundation
import PromiseKit
import RealmSwift
import Shared
import UIKit

class ZoneManager {
    let locationManager: CLLocationManager
    let collector: ZoneManagerCollector
    let processor: ZoneManagerProcessor
    let regionFilter: ZoneManagerRegionFilter
    let zones: AnyRealmCollection<RLMZone>

    private var notificationTokens = [NotificationToken]()

    init(
        locationManager: CLLocationManager = .init(),
        collector: ZoneManagerCollector = ZoneManagerCollectorImpl(),
        processor: ZoneManagerProcessor = ZoneManagerProcessorImpl(),
        regionFilter: ZoneManagerRegionFilter = ZoneManagerRegionFilterImpl()
    ) {
        self.locationManager = locationManager
        self.collector = collector
        self.processor = processor
        self.regionFilter = regionFilter
        self.zones = AnyRealmCollection(
            Current.realm()
                .objects(RLMZone.self)
                .filter("TrackingEnabled == true")
        )

        self.collector.delegate = self
        self.processor.delegate = self

        log(state: .initialize)

        updateLocationManager(isInitial: true)
        zones.realm?.refresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(locationSettingDidChange),
            name: SettingsStore.locationRelatedSettingDidChange,
            object: nil
        )
    }

    deinit {
        Current.Log.info("going away")
    }

    @objc private func locationSettingDidChange() {
        updateLocationManager(isInitial: false)
    }

    private func updateLocationManager(isInitial: Bool) {
        with(locationManager) {
            $0.delegate = collector
            $0.allowsBackgroundLocationUpdates = true
            $0.pausesLocationUpdatesAutomatically = false

            if Current.settingsStore.locationSources.significantLocationChange {
                Current.Log.info("started monitoring siglog changes")
                $0.startMonitoringSignificantLocationChanges()
            } else {
                Current.Log.info("not monitoring siglog changes")
                $0.stopMonitoringSignificantLocationChanges()
            }
        }

        if isInitial {
            notificationTokens.append(zones.observe { [weak self] change in
                switch change {
                case let .initial(collection), .update(let collection, deletions: _, insertions: _, modifications: _):
                    self?.sync(zones: AnyCollection(collection))
                case let .error(error):
                    Current.Log.error("couldn't sync zones: \(error)")
                }
            })
        } else {
            sync(zones: AnyCollection(zones))
        }
    }

    private func log(state: ZoneManagerState) {
        Current.Log.info(state)
    }

    private func perform(event: ZoneManagerEvent) {
        let logPayload: [String: String] = [
            "start_ssid": Current.connectivity.currentWiFiSSID() ?? "none",
            "event": event.description,
        ]

        // although technically the processor also does this, it does it after some async processing.
        // let's be very confident that we're not going to miss out on an update due to being suspended
        Current.backgroundTask(withName: "zone-manager-perform-event") { _ in
            processor.perform(event: event)
        }.get { [weak self] _ in
            // a location change means we should consider changing our monitored regions
            // ^ not tap for this side effect because we don't want to do this on failure
            guard let self = self else { return }
            self.sync(zones: AnyCollection(self.zones))
        }.then {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Updated location",
                type: .locationUpdate,
                payload: logPayload
            ))
        }.catch { error in
            Current.Log.error("final error for \(event): \(error)")

            var updatedPayload = logPayload
            updatedPayload["error"] = String(describing: error)

            Current.clientEventStore.addEvent(ClientEvent(
                text: "Didn't update: \(error.localizedDescription)",
                type: .locationUpdate,
                payload: updatedPayload
            )).cauterize()
        }
    }

    private func fire(event: ZoneManagerEvent) {
        guard let zone = event.associatedZone,
              let server = Current.servers.server(forServerIdentifier: zone.serverIdentifier) else { return }

        switch event.eventType {
        case let .region(region, state):
            let api = Current.api(for: server)
            let eventInfo = api.zoneStateEvent(region: region, state: state, zone: zone)
            api.CreateEvent(eventType: eventInfo.eventType, eventData: eventInfo.eventData).cauterize()
        case .locationChange:
            break
        }
    }

    private func sync(zones: AnyCollection<RLMZone>) {
        let currentRegions = locationManager.monitoredRegions
        let desiredRegions = regionFilter.regions(
            from: zones,
            currentRegions: AnyCollection(currentRegions),
            lastLocation: locationManager.location
        )

        let actual = Set(currentRegions.map(ZoneManagerEquatableRegion.init(region:)))
        let expected: Set<ZoneManagerEquatableRegion>

        if Current.settingsStore.locationSources.zone {
            expected = Set(desiredRegions.map(ZoneManagerEquatableRegion.init(region:)))
        } else {
            expected = Set()
        }

        let needsRemoval = actual.subtracting(expected)
        let needsAddition = expected.subtracting(actual)

        // process removals before additions
        // this is important because the system is focused on identifier
        for region in needsRemoval.map(\.region) {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Ending monitoring \(region.identifier)",
                type: .locationUpdate,
                payload: [
                    "region": String(describing: region),
                ]
            )).cauterize()
            locationManager.stopMonitoring(for: region)
        }

        for region in needsAddition.map(\.region) {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Initially monitoring \(region.identifier)",
                type: .locationUpdate,
                payload: [
                    "region": String(describing: region),
                ]
            )).cauterize()

            collector.ignoreNextState(for: region)
            locationManager.startMonitoring(for: region)
        }

        let counts = (
            beacon: expected.filter { $0.region is CLBeaconRegion }.count,
            circular: expected.filter { $0.region is CLCircularRegion }.count,
            zone: Set(zones).count
        )

        Current.Log.info {
            let info = [
                "available \(zones.count)",
                "enabled \(Current.settingsStore.locationSources.zone)",
                "monitoring \(expected.count) (\(counts))",
                "started \(needsAddition.count)",
                "ended \(needsRemoval.count)",
            ]
            return info.joined(separator: ", ")
        }
    }
}

extension ZoneManager: ZoneManagerCollectorDelegate {
    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState) {
        log(state: state)
    }

    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent) {
        fire(event: event)
        perform(event: event)
    }
}

extension ZoneManager: ZoneManagerProcessorDelegate {
    func processor(_ processor: ZoneManagerProcessor, didLog state: ZoneManagerState) {
        log(state: state)
    }
}
