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
    var startedRangingConstraints = [CLBeaconIdentityConstraint]()
    var stoppedRangingConstraints = [CLBeaconIdentityConstraint]()
    var requestAlwaysAuthorizationCount = 0
    var startUpdatingLocationCount = 0
    var stopUpdatingLocationCount = 0
    var overrideAuthorizationStatus: CLAuthorizationStatus = .authorizedAlways

    override var monitoredRegions: Set<CLRegion> {
        monitoredRegionsReadsWereOnMainThread.append(Thread.isMainThread)
        return overrideMonitoredRegions
    }

    override var authorizationStatus: CLAuthorizationStatus {
        overrideAuthorizationStatus
    }

    override func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCount += 1
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

    override func startRangingBeacons(satisfying constraint: CLBeaconIdentityConstraint) {
        startedRangingConstraints.append(constraint)
    }

    override func stopRangingBeacons(satisfying constraint: CLBeaconIdentityConstraint) {
        stoppedRangingConstraints.append(constraint)
    }

    override func startUpdatingLocation() {
        startUpdatingLocationCount += 1
    }

    override func stopUpdatingLocation() {
        stopUpdatingLocationCount += 1
    }
}
