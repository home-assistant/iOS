import CoreLocation
import Foundation

class FakeCLLocationManager: CLLocationManager {
    var startMonitoringRegions = [CLRegion]()
    var stopMonitoringRegions = [CLRegion]()
    var isMonitoringSigLocChanges = false
    var overrideMonitoredRegions = Set<CLRegion>()
    var requestedRegions = [CLRegion]()

    override var monitoredRegions: Set<CLRegion> {
        overrideMonitoredRegions
    }

    override func startMonitoring(for region: CLRegion) {
        startMonitoringRegions.append(region)
        overrideMonitoredRegions.insert(region)
    }

    override func stopMonitoring(for region: CLRegion) {
        stopMonitoringRegions.append(region)
        overrideMonitoredRegions.remove(region)
    }

    override func startMonitoringSignificantLocationChanges() {
        isMonitoringSigLocChanges = true
    }

    override func stopMonitoringSignificantLocationChanges() {
        isMonitoringSigLocChanges = false
    }

    override func requestState(for region: CLRegion) {
        requestedRegions.append(region)
    }
}
