import CoreLocation
import PromiseKit
import Shared

protocol ZoneManagerCollectorDelegate: AnyObject {
    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState)
    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent)
}

protocol ZoneManagerCollector: CLLocationManagerDelegate {
    var delegate: ZoneManagerCollectorDelegate? { get set }
    func ignoreNextState(for region: CLRegion)
}

class ZoneManagerCollectorImpl: NSObject, ZoneManagerCollector {
    weak var delegate: ZoneManagerCollectorDelegate?

    private var ignoredNextRegions = Set<CLRegion>()

    func ignoreNextState(for region: CLRegion) {
        ignoredNextRegions.insert(region)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        delegate?.collector(self, didLog: .didError(error))
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        delegate?.collector(self, didLog: .didFailMonitoring(region, error))
    }

    func locationManager(
        _ manager: CLLocationManager,
        didStartMonitoringFor region: CLRegion
    ) {
        delegate?.collector(self, didLog: .didStartMonitoring(region))
    }

    func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        guard !ignoredNextRegions.contains(region) else {
            ignoredNextRegions.remove(region)
            return
        }

        let zone = Current.realm()
            .objects(RLMZone.self)
            .first(where: {
                $0.identifier == region.identifier ||
                    $0.identifier == region.identifier.components(separatedBy: "@").first
            })

        let event = ZoneManagerEvent(
            eventType: .region(region, state),
            associatedZone: zone
        )

        delegate?.collector(self, didCollect: event)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let event = ZoneManagerEvent(
            eventType: .locationChange(locations)
        )

        delegate?.collector(self, didCollect: event)
    }
}
