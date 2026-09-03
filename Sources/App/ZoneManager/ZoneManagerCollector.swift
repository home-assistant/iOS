import CoreLocation
import Shared
import UIKit

protocol ZoneManagerCollectorDelegate: AnyObject {
    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState)
    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent)
}

protocol ZoneManagerCollector: CLLocationManagerDelegate {
    var delegate: ZoneManagerCollectorDelegate? { get set }
    func ignoreNextState(for region: CLRegion)
    func startForegroundBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager)
    func stopForegroundBeaconScanning(manager: CLLocationManager)
    func startBackgroundBeaconMonitoring(in regions: Set<CLRegion>, manager: CLLocationManager)
    func stopBackgroundBeaconMonitoring(manager: CLLocationManager)
    func startOpportunisticBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager)
}

class ZoneManagerCollectorImpl: NSObject, ZoneManagerCollector {
    private struct PendingBeaconEntry {
        let event: ZoneManagerEvent
        let constraint: CLBeaconIdentityConstraint
        let timeout: DispatchWorkItem
    }

    private struct ForegroundBeaconEntry {
        let event: ZoneManagerEvent
        let region: CLBeaconRegion
        let constraint: CLBeaconIdentityConstraint
    }

    private struct BeaconReconciliationState {
        var emptySampleCount = 0
        var firstEmptySampleAt: Date?
    }

    weak var delegate: ZoneManagerCollectorDelegate?

    private var ignoredNextRegions = Set<CLRegion>()
    private var pendingBeaconEntries = [String: PendingBeaconEntry]()
    private var foregroundBeaconEntries = [String: ForegroundBeaconEntry]()
    private var foregroundBeaconIdentifiersInside = Set<String>()
    private var opportunisticBeaconEntries = [String: ForegroundBeaconEntry]()
    private var backgroundBeaconRegions = [String: CLBeaconRegion]()
    private var beaconReconciliationStates = [String: BeaconReconciliationState]()
    private var beaconRangingRetryCounts = [CLBeaconIdentityConstraint: Int]()
    private var beaconRangingRetryWorkItems = [CLBeaconIdentityConstraint: DispatchWorkItem]()
    private var opportunisticBeaconScanTimeout: DispatchWorkItem?
    private let beaconVerificationTimeout: TimeInterval
    private let opportunisticBeaconScanDuration: TimeInterval
    private let beaconExitReconciliationDuration: TimeInterval
    private let beaconExitMinimumEmptySamples: Int
    private let beaconRangingRetryLimit: Int
    private let beaconRangingRetryDelay: TimeInterval
    private let strongFarBeaconRSSIThreshold: Int
    private let backgroundExecution: BeaconScanBackgroundExecution

    init(
        beaconVerificationTimeout: TimeInterval = 25,
        opportunisticBeaconScanDuration: TimeInterval = 25,
        beaconExitReconciliationDuration: TimeInterval = 8,
        beaconExitMinimumEmptySamples: Int = 3,
        beaconRangingRetryLimit: Int = 2,
        beaconRangingRetryDelay: TimeInterval = 1,
        strongFarBeaconRSSIThreshold: Int = -82,
        backgroundExecution: BeaconScanBackgroundExecution = UIApplicationBeaconScanBackgroundExecution()
    ) {
        self.beaconVerificationTimeout = beaconVerificationTimeout
        self.opportunisticBeaconScanDuration = opportunisticBeaconScanDuration
        self.beaconExitReconciliationDuration = beaconExitReconciliationDuration
        self.beaconExitMinimumEmptySamples = beaconExitMinimumEmptySamples
        self.beaconRangingRetryLimit = beaconRangingRetryLimit
        self.beaconRangingRetryDelay = beaconRangingRetryDelay
        self.strongFarBeaconRSSIThreshold = strongFarBeaconRSSIThreshold
        self.backgroundExecution = backgroundExecution
    }

    func ignoreNextState(for region: CLRegion) {
        ignoredNextRegions.insert(region)
    }

    func startForegroundBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager) {
        let desiredEntries = beaconEntries(in: regions)
        let identifiersToRemove = foregroundBeaconEntries.compactMap { identifier, entry in
            desiredEntries[identifier]?.constraint == entry.constraint ? nil : identifier
        }
        let removedConstraints = identifiersToRemove.compactMap { identifier in
            foregroundBeaconEntries.removeValue(forKey: identifier)?.constraint
        }

        for identifier in identifiersToRemove
            where pendingBeaconEntries[identifier] == nil && opportunisticBeaconEntries[identifier] == nil {
            foregroundBeaconIdentifiersInside.remove(identifier)
            beaconReconciliationStates.removeValue(forKey: identifier)
        }
        for constraint in Set(removedConstraints) {
            stopRangingIfUnused(constraint, manager: manager)
        }

        for (identifier, entry) in desiredEntries where foregroundBeaconEntries[identifier] == nil {
            let wasActive = hasActiveRangingEntry(for: entry.constraint)
            foregroundBeaconEntries[identifier] = entry
            startRangingIfNeeded(entry.constraint, wasActive: wasActive, manager: manager)
        }
    }

    func startBackgroundBeaconMonitoring(in regions: Set<CLRegion>, manager: CLLocationManager) {
        let desiredRegions = Dictionary(
            uniqueKeysWithValues: regions.compactMap { region -> (String, CLBeaconRegion)? in
                guard let beaconRegion = region as? CLBeaconRegion else { return nil }
                return (beaconRegion.identifier, beaconRegion)
            }
        )
        if desiredRegions.isEmpty {
            backgroundBeaconRegions.removeAll()
            stopOpportunisticBeaconScanning(manager: manager)
            return
        }
        let regionsAreUnchanged = sameBeaconRegions(backgroundBeaconRegions, desiredRegions)
        guard !regionsAreUnchanged || opportunisticBeaconEntries.isEmpty else { return }

        backgroundBeaconRegions = desiredRegions
        startOpportunisticBeaconScanning(
            in: Set(desiredRegions.values.map { $0 as CLRegion }),
            manager: manager
        )
        recordBeaconBackgroundEvent("Reconciled bounded background beacon ranging")
    }

    func stopBackgroundBeaconMonitoring(manager: CLLocationManager) {
        let wasMonitoring = !backgroundBeaconRegions.isEmpty
        backgroundBeaconRegions.removeAll()
        stopOpportunisticBeaconScanning(manager: manager)
        if wasMonitoring {
            recordBeaconBackgroundEvent("Stopped bounded background beacon ranging")
        }
    }

    func stopForegroundBeaconScanning(manager: CLLocationManager) {
        let entries = foregroundBeaconEntries
        foregroundBeaconEntries.removeAll()

        for identifier in entries.keys
            where pendingBeaconEntries[identifier] == nil && opportunisticBeaconEntries[identifier] == nil {
            foregroundBeaconIdentifiersInside.remove(identifier)
            beaconReconciliationStates.removeValue(forKey: identifier)
        }

        for constraint in Set(entries.values.map(\.constraint)) {
            stopRangingIfUnused(constraint, manager: manager)
        }
    }

    func startOpportunisticBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager) {
        // Foreground ranging is already continuous, so an additional timed scan
        // would only duplicate work.
        guard foregroundBeaconEntries.isEmpty else { return }

        stopOpportunisticBeaconScanning(manager: manager)

        for (identifier, entry) in beaconEntries(in: regions) {
            let wasActive = hasActiveRangingEntry(for: entry.constraint)
            opportunisticBeaconEntries[identifier] = entry
            startRangingIfNeeded(entry.constraint, wasActive: wasActive, manager: manager)
        }

        guard !opportunisticBeaconEntries.isEmpty else { return }

        beginBackgroundScanExecution(manager: manager)

        let timeout = DispatchWorkItem { [weak self, weak manager] in
            guard let self, let manager else { return }
            self.reconcileBeaconExits(manager: manager)
            self.stopOpportunisticBeaconScanning(manager: manager)
        }
        opportunisticBeaconScanTimeout = timeout
        DispatchQueue.main.asyncAfter(
            deadline: .now() + opportunisticBeaconScanDuration,
            execute: timeout
        )
    }

    private func stopOpportunisticBeaconScanning(manager: CLLocationManager) {
        opportunisticBeaconScanTimeout?.cancel()
        opportunisticBeaconScanTimeout = nil

        let entries = opportunisticBeaconEntries
        opportunisticBeaconEntries.removeAll()

        for identifier in entries.keys
            where foregroundBeaconEntries[identifier] == nil && pendingBeaconEntries[identifier] == nil {
            foregroundBeaconIdentifiersInside.remove(identifier)
            beaconReconciliationStates.removeValue(forKey: identifier)
        }
        for constraint in Set(entries.values.map(\.constraint)) {
            stopRangingIfUnused(constraint, manager: manager)
        }
        endBackgroundScanExecutionIfIdle()
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        rangingBeaconsDidFailFor beaconConstraint: CLBeaconIdentityConstraint,
        withError error: Error
    ) {
        delegate?.collector(self, didLog: .didFailRanging(beaconConstraint, error))

        guard hasActiveRangingEntry(for: beaconConstraint),
              beaconRangingRetryCounts[beaconConstraint, default: 0] < beaconRangingRetryLimit,
              beaconRangingRetryWorkItems[beaconConstraint] == nil else { return }

        beaconRangingRetryCounts[beaconConstraint, default: 0] += 1
        let retry = DispatchWorkItem { [weak self, weak manager] in
            guard let self else { return }
            self.beaconRangingRetryWorkItems.removeValue(forKey: beaconConstraint)
            guard self.hasActiveRangingEntry(for: beaconConstraint) else { return }
            manager?.startRangingBeacons(satisfying: beaconConstraint)
        }
        beaconRangingRetryWorkItems[beaconConstraint] = retry
        DispatchQueue.main.asyncAfter(deadline: .now() + beaconRangingRetryDelay, execute: retry)
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

        let event = Self.event(for: region, state: state)

        if let beaconRegion = region as? CLBeaconRegion {
            switch state {
            case .inside:
                guard !foregroundBeaconIdentifiersInside.contains(beaconRegion.identifier) else { return }
                verifyBeaconEntry(event, region: beaconRegion, manager: manager)
                return
            case .outside:
                cancelPendingBeaconEntry(for: beaconRegion, manager: manager)
                cancelOpportunisticBeaconEntry(for: beaconRegion, manager: manager)
                foregroundBeaconIdentifiersInside.remove(beaconRegion.identifier)
            case .unknown:
                break
            }
        }

        delegate?.collector(self, didCollect: event)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {
        didRange(
            samples: beacons.map { RangedBeaconSample(proximity: $0.proximity, rssi: $0.rssi) },
            satisfying: beaconConstraint,
            manager: manager
        )
    }

    func didRange(
        samples: [RangedBeaconSample],
        satisfying beaconConstraint: CLBeaconIdentityConstraint,
        manager: CLLocationManager
    ) {
        beaconRangingRetryCounts.removeValue(forKey: beaconConstraint)
        beaconRangingRetryWorkItems.removeValue(forKey: beaconConstraint)?.cancel()

        let pendingIdentifiers = identifiers(in: pendingBeaconEntries, matching: beaconConstraint)
        let foregroundIdentifiers = identifiers(in: foregroundBeaconEntries, matching: beaconConstraint)
        let opportunisticIdentifiers = identifiers(in: opportunisticBeaconEntries, matching: beaconConstraint)
        let identifiers = Set(pendingIdentifiers + foregroundIdentifiers + opportunisticIdentifiers)

        guard let detectedBeacon = samples.first(where: isBeaconInsideRange) else {
            reconcileEmptyBeaconSample(identifiers: Array(identifiers), manager: manager)
            return
        }

        identifiers.forEach { beaconReconciliationStates.removeValue(forKey: $0) }
        var events = [ZoneManagerEvent]()
        acceptPendingSamples(for: pendingIdentifiers, events: &events)
        acceptForegroundSamples(for: foregroundIdentifiers, events: &events)
        acceptOpportunisticSamples(for: opportunisticIdentifiers, events: &events)

        stopRangingIfUnused(beaconConstraint, manager: manager)

        endBackgroundScanExecutionIfIdle()

        let diagnostic = BeaconDiagnostic(
            proximity: Self.diagnosticProximity(detectedBeacon.proximity),
            rssi: detectedBeacon.rssi,
            isAppActive: UIApplication.shared.applicationState == .active
        )
        events.forEach { event in
            var event = event
            event.beaconDiagnostic = diagnostic
            delegate?.collector(self, didCollect: event)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        startOpportunisticBeaconScanning(in: manager.monitoredRegions, manager: manager)

        let event = ZoneManagerEvent(
            eventType: .locationChange(locations)
        )

        delegate?.collector(self, didCollect: event)
    }

    private func verifyBeaconEntry(
        _ event: ZoneManagerEvent,
        region: CLBeaconRegion,
        manager: CLLocationManager
    ) {
        let identifier = region.identifier
        let constraint = region.beaconIdentityConstraint

        if let pending = pendingBeaconEntries.removeValue(forKey: identifier) {
            pending.timeout.cancel()
            stopRangingIfUnused(pending.constraint, manager: manager)
        }

        let timeout = DispatchWorkItem { [weak self, weak manager] in
            guard let self,
                  let pending = self.pendingBeaconEntries.removeValue(forKey: identifier) else { return }

            if let manager {
                self.stopRangingIfUnused(pending.constraint, manager: manager)
            }
            self.endBackgroundScanExecutionIfIdle()
            self.delegate?.collector(
                self,
                didLog: .didIgnore(event, ZoneManagerIgnoreReason.beaconEntryNotVerified)
            )
        }

        let wasActive = hasActiveRangingEntry(for: constraint)
        pendingBeaconEntries[identifier] = PendingBeaconEntry(
            event: event,
            constraint: constraint,
            timeout: timeout
        )
        beginBackgroundScanExecution(manager: manager)
        startRangingIfNeeded(constraint, wasActive: wasActive, manager: manager)
        DispatchQueue.main.asyncAfter(deadline: .now() + beaconVerificationTimeout, execute: timeout)
    }

    private func cancelPendingBeaconEntry(for region: CLBeaconRegion, manager: CLLocationManager) {
        guard let pending = pendingBeaconEntries.removeValue(forKey: region.identifier) else { return }

        pending.timeout.cancel()
        stopRangingIfUnused(pending.constraint, manager: manager)
        endBackgroundScanExecutionIfIdle()
    }

    private func cancelOpportunisticBeaconEntry(for region: CLBeaconRegion, manager: CLLocationManager) {
        guard let entry = opportunisticBeaconEntries.removeValue(forKey: region.identifier) else { return }

        stopRangingIfUnused(entry.constraint, manager: manager)
        endBackgroundScanExecutionIfIdle()
    }

    private func beginBackgroundScanExecution(manager: CLLocationManager) {
        // Ranging alone does not keep a suspended app executable. Acquire the lease before
        // starting Core Location work so near samples can arrive during the bounded scan.
        backgroundExecution.begin { [weak self, weak manager] in
            guard let self, let manager else { return }

            let constraints = Set(self.pendingBeaconEntries.values.map(\.constraint))
            for pending in self.pendingBeaconEntries.values {
                pending.timeout.cancel()
            }
            self.pendingBeaconEntries.removeAll()
            for constraint in constraints {
                self.stopRangingIfUnused(constraint, manager: manager)
            }
            self.stopOpportunisticBeaconScanning(manager: manager)
        }
    }

    private func endBackgroundScanExecutionIfIdle() {
        guard pendingBeaconEntries.isEmpty, opportunisticBeaconEntries.isEmpty else {
            return
        }
        backgroundExecution.end()
    }

    private func reconcileEmptyBeaconSample(identifiers: [String], manager: CLLocationManager) {
        let now = Date()

        for identifier in Set(identifiers) where foregroundBeaconIdentifiersInside.contains(identifier) {
            var state = beaconReconciliationStates[identifier] ?? BeaconReconciliationState()
            state.emptySampleCount += 1
            state.firstEmptySampleAt = state.firstEmptySampleAt ?? now
            beaconReconciliationStates[identifier] = state
        }

        reconcileBeaconExits(manager: manager, now: now)
    }

    private func reconcileBeaconExits(manager: CLLocationManager, now: Date = Date()) {
        let identifiersToExit = beaconReconciliationStates.compactMap { identifier, state -> String? in
            guard state.emptySampleCount >= beaconExitMinimumEmptySamples,
                  let firstEmptySampleAt = state.firstEmptySampleAt,
                  now.timeIntervalSince(firstEmptySampleAt) >= beaconExitReconciliationDuration,
                  foregroundBeaconIdentifiersInside.contains(identifier),
                  foregroundBeaconEntries[identifier] != nil || opportunisticBeaconEntries[identifier] != nil
            else { return nil }

            return identifier
        }

        for identifier in identifiersToExit {
            guard foregroundBeaconIdentifiersInside.remove(identifier) != nil,
                  let entry = foregroundBeaconEntries[identifier] ?? opportunisticBeaconEntries[identifier]
            else { continue }

            beaconReconciliationStates.removeValue(forKey: identifier)
            delegate?.collector(
                self,
                didCollect: Self.event(for: entry.region, state: .outside)
            )
        }
    }

    private func beaconEntries(in regions: Set<CLRegion>) -> [String: ForegroundBeaconEntry] {
        Dictionary(uniqueKeysWithValues: regions.compactMap { region -> (String, ForegroundBeaconEntry)? in
            guard let beaconRegion = region as? CLBeaconRegion else { return nil }
            let event = Self.event(for: beaconRegion, state: .inside)
            guard event.associatedZone != nil else { return nil }
            return (
                beaconRegion.identifier,
                ForegroundBeaconEntry(
                    event: event,
                    region: beaconRegion,
                    constraint: beaconRegion.beaconIdentityConstraint
                )
            )
        })
    }

    private func sameBeaconRegions(
        _ lhs: [String: CLBeaconRegion],
        _ rhs: [String: CLBeaconRegion]
    ) -> Bool {
        lhs.count == rhs.count && lhs.allSatisfy { identifier, region in
            rhs[identifier]?.beaconIdentityConstraint == region.beaconIdentityConstraint
        }
    }

    private func identifiers(
        in entries: [String: PendingBeaconEntry],
        matching constraint: CLBeaconIdentityConstraint
    ) -> [String] {
        entries.compactMap { $0.value.constraint == constraint ? $0.key : nil }
    }

    private func identifiers(
        in entries: [String: ForegroundBeaconEntry],
        matching constraint: CLBeaconIdentityConstraint
    ) -> [String] {
        entries.compactMap { $0.value.constraint == constraint ? $0.key : nil }
    }

    private func acceptPendingSamples(for identifiers: [String], events: inout [ZoneManagerEvent]) {
        for identifier in identifiers {
            guard let pending = pendingBeaconEntries.removeValue(forKey: identifier) else { continue }
            pending.timeout.cancel()
            acceptCurrentSample(for: identifier, event: pending.event, events: &events)
        }
    }

    private func acceptForegroundSamples(for identifiers: [String], events: inout [ZoneManagerEvent]) {
        for identifier in identifiers {
            guard let foreground = foregroundBeaconEntries[identifier] else { continue }
            acceptCurrentSample(for: identifier, event: foreground.event, events: &events)
        }
    }

    private func acceptOpportunisticSamples(for identifiers: [String], events: inout [ZoneManagerEvent]) {
        for identifier in identifiers {
            guard let opportunistic = opportunisticBeaconEntries.removeValue(forKey: identifier) else { continue }
            acceptCurrentSample(for: identifier, event: opportunistic.event, events: &events)
            if foregroundBeaconEntries[identifier] == nil && pendingBeaconEntries[identifier] == nil {
                foregroundBeaconIdentifiersInside.remove(identifier)
                beaconReconciliationStates.removeValue(forKey: identifier)
            }
        }
    }

    private func acceptCurrentSample(
        for identifier: String,
        event: ZoneManagerEvent,
        events: inout [ZoneManagerEvent]
    ) {
        let wasInside = foregroundBeaconIdentifiersInside.contains(identifier)
        foregroundBeaconIdentifiersInside.insert(identifier)
        guard !wasInside,
              event.associatedZone?.inRegion != true,
              !events.contains(event) else { return }
        events.append(event)
    }

    private func startRangingIfNeeded(
        _ constraint: CLBeaconIdentityConstraint,
        wasActive: Bool,
        manager: CLLocationManager
    ) {
        guard !wasActive else { return }
        clearRangingRetryState(for: constraint)
        manager.startRangingBeacons(satisfying: constraint)
    }

    private func stopRangingIfUnused(
        _ constraint: CLBeaconIdentityConstraint,
        manager: CLLocationManager
    ) {
        guard !hasActiveRangingEntry(for: constraint) else { return }
        clearRangingRetryState(for: constraint)
        manager.stopRangingBeacons(satisfying: constraint)
    }

    private func clearRangingRetryState(for constraint: CLBeaconIdentityConstraint) {
        beaconRangingRetryCounts.removeValue(forKey: constraint)
        beaconRangingRetryWorkItems.removeValue(forKey: constraint)?.cancel()
    }

    private func isBeaconInsideRange(_ beacon: RangedBeaconSample) -> Bool {
        guard beacon.rssi != 0 else { return false }

        switch beacon.proximity {
        case .immediate, .near:
            return true
        // Core Location can briefly classify a physically close beacon as `.far` while RSSI stabilizes.
        // Accept only a strong far sample so background Entry does not depend on a later `.near` callback.
        case .far:
            return beacon.rssi >= strongFarBeaconRSSIThreshold
        case .unknown:
            return false
        @unknown default:
            return false
        }
    }

    private static func diagnosticProximity(_ proximity: CLProximity) -> String {
        switch proximity {
        case .immediate:
            return "immediate"
        case .near:
            return "near"
        case .far:
            return "far"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }

    private func hasActiveRangingEntry(for constraint: CLBeaconIdentityConstraint) -> Bool {
        pendingBeaconEntries.values.contains { $0.constraint == constraint } ||
            foregroundBeaconEntries.values.contains { $0.constraint == constraint } ||
            opportunisticBeaconEntries.values.contains { $0.constraint == constraint }
    }

    private func recordBeaconBackgroundEvent(_ text: String, payload: [String: String] = [:]) {
        Current.clientEventStore.addEvent(ClientEvent(
            text: text,
            type: .locationUpdate,
            payload: payload
        ))
    }

    private static func event(for region: CLRegion, state: CLRegionState) -> ZoneManagerEvent {
        // regions for small zones are suffixed with "@<angle>"; the zone's
        // identifier is the prefix
        let baseIdentifier = region.identifier.components(separatedBy: "@").first ?? region.identifier
        var zone = AppZone.zone(identifier: region.identifier)
        if zone == nil, baseIdentifier != region.identifier {
            zone = AppZone.zone(identifier: baseIdentifier)
        }

        return ZoneManagerEvent(
            eventType: .region(region, state),
            associatedZone: zone
        )
    }
}
