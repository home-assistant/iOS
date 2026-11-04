import CoreLocation
import Foundation

class FakeCLLocationManager: CLLocationManager {
    var startMonitoringRegions = [CLRegion]()
    var stopMonitoringRegions = [CLRegion]()
    var isMonitoringSigLocChanges = false
    var overrideMonitoredRegions = Set<CLRegion>()
    var requestedRegions = [CLRegion]()
    var monitoredRegionsReadsWereOnMainThread = [Bool]()
    var startMonitoringCallsWereOnMainThread = [Bool]()

    override var monitoredRegions: Set<CLRegion> {
        monitoredRegionsReadsWereOnMainThread.append(Thread.isMainThread)
        return overrideMonitoredRegions
    }

    override func startMonitoring(for region: CLRegion) {
        startMonitoringCallsWereOnMainThread.append(Thread.isMainThread)
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
