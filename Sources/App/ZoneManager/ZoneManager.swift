import Foundation
import PromiseKit
import CoreLocation
import Shared
import UIKit
import RealmSwift

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
        self.collector = collector
        self.processor = processor
        self.regionFilter = regionFilter
        self.zones = AnyRealmCollection(
            Current.realm()
            .objects(RLMZone.self)
            .filter("TrackingEnabled == true")
        )

        self.locationManager = with(locationManager) {
            $0.allowsBackgroundLocationUpdates = true
            $0.pausesLocationUpdatesAutomatically = false
        }

        self.collector.delegate = self
        self.processor.delegate = self
        notificationTokens.append(self.zones.observe { [weak self] change in
            switch change {
            case .initial(let collection), .update(let collection, deletions: _, insertions: _, modifications: _):
                self?.sync(zones: AnyCollection(collection))
            case .error(let error):
                Current.Log.error("couldn't sync zones: \(error)")
            }
        })

        log(state: .initialize)
        zones.realm?.refresh()
        locationManager.delegate = collector
        locationManager.startMonitoringSignificantLocationChanges()
    }

    deinit {
        Current.Log.info("going away")
    }

    private func log(state: ZoneManagerState) {
         Current.Log.info(state)
    }

    private func perform(event: ZoneManagerEvent) {
        let logPayload: [String: String] = [
            "start_ssid": Current.connectivity.currentWiFiSSID() ?? "none",
            "event": event.description
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
        }.done {
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
            ))
        }
    }

    private func fire(event: ZoneManagerEvent) {
        guard let eventInfo = event.asFirableEvent() else {
            return
        }

        Current.api.then { api in
            api.CreateEvent(eventType: eventInfo.eventType, eventData: eventInfo.eventData)
        }.cauterize()
    }

    private func sync(zones: AnyCollection<RLMZone>) {
        let currentRegions = locationManager.monitoredRegions
        let desiredRegions = regionFilter.regions(
            from: zones,
            currentRegions: AnyCollection(currentRegions),
            lastLocation: locationManager.location
        )

        let actual = Set(currentRegions.map(ZoneManagerEquatableRegion.init(region:)))
        let expected = Set(desiredRegions.map(ZoneManagerEquatableRegion.init(region:)))

        let needsRemoval = actual.subtracting(expected)
        let needsAddition = expected.subtracting(actual)

        // process removals before additions
        // this is important because the system is focused on identifier
        for region in needsRemoval.map(\.region) {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Ending monitoring \(region.identifier)",
                type: .locationUpdate,
                payload: [
                    "region": String(describing: region)
                ]
            ))
            locationManager.stopMonitoring(for: region)
        }

        for region in needsAddition.map(\.region) {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Initially monitoring \(region.identifier)",
                type: .locationUpdate,
                payload: [
                    "region": String(describing: region)
                ]
            ))

            collector.ignoreNextState(for: region)
            locationManager.startMonitoring(for: region)
        }

        let counts = (
            beacon: expected.filter { $0.region is CLBeaconRegion }.count,
            circular: expected.filter {$0.region is CLCircularRegion }.count,
            zone: Set(zones).count
        )

        Current.Log.info {
            let info = [
                "monitoring \(expected.count) (\(counts))",
                "started \(needsAddition.count)",
                "ended \(needsRemoval.count)"
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
