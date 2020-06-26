import Foundation
import PromiseKit
import CoreLocation
import Shared
import UIKit

class ZoneManager {
    let locationManager: CLLocationManager
    let collector: ZoneManagerCollector
    let processor: ZoneManagerProcessor

    init(
        locationManager: CLLocationManager = .init(),
        collector: ZoneManagerCollector = ZoneManagerCollectorImpl(),
        processor: ZoneManagerProcessor = ZoneManagerProcessorImpl()
    ) {
        self.collector = collector
        self.processor = processor

        self.locationManager = with(locationManager) {
            $0.allowsBackgroundLocationUpdates = true
            $0.pausesLocationUpdatesAutomatically = false
        }

        // we separate out the delegate from ourselves to force a clean separation from location manager
        self.collector.delegate = self
        self.processor.delegate = self

        log(state: .initialize)
        syncZones().cauterize()
        locationManager.delegate = collector
        locationManager.startMonitoringSignificantLocationChanges()
    }

    private func log(state: ZoneManagerState) {
         Current.Log.info(state)
    }

    private func perform(event: ZoneManagerEvent) {
        let logPayload: [String: Any] = [
            "start_ssid": Current.connectivity.currentWiFiSSID() ?? "none",
            "event": event.description
        ]

        // although technically the processor also does this, it does it after some async processing.
        // let's be very cofident that we're not going to miss out on an update due to being suspended
        UIApplication.shared.backgroundTask(withName: "zone-manager-perform-event") { _ in
            processor.perform(event: event)
        }.done {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Updated location",
                type: .locationUpdate,
                payload: logPayload
            ))
        }.catch { error in
            Current.Log.error("final error for \(event): \(error)")
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Failed updating: \(error.localizedDescription)",
                type: .locationUpdate,
                payload: logPayload
            ))
        }
    }

    internal func syncZones() -> Promise<Void> {
        let expected = Set(
            Current.realm()
                .objects(RLMZone.self)
                .map { $0.region() }
                .map(ZoneManagerEquatableRegion.init(region:))
        )
        let actual = Set(
            locationManager
                .monitoredRegions
                .map(ZoneManagerEquatableRegion.init(region:))
        )

        let needsRemoval = actual.subtracting(expected)
        let needsAddition = expected.subtracting(actual)

        // process removals before additions
        // this is important because the system is focused on identifier
        for region in needsRemoval.map(\.region) {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Ending monitoring \(region)",
                type: .locationUpdate
            ))
            locationManager.stopMonitoring(for: region)
        }

        for region in needsAddition.map(\.region) {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Initially monitoring \(region)",
                type: .locationUpdate
            ))
            locationManager.startMonitoring(for: region)
        }

        Current.Log.info {
            [
                "monitoring \(expected.count)",
                "started \(needsAddition.count)",
                "ended \(needsRemoval.count)"
            ].joined(separator: ", ")
        }
        return .value(())
    }
}

extension ZoneManager: ZoneManagerCollectorDelegate {
    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState) {
        log(state: state)
    }

    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent) {
        perform(event: event)
    }
}

extension ZoneManager: ZoneManagerProcessorDelegate {
    func processor(_ processor: ZoneManagerProcessor, didLog state: ZoneManagerState) {
        log(state: state)
    }
}
