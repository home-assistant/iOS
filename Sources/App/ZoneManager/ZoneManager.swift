import CoreLocation
import Foundation
import GRDB
import PromiseKit
import Shared
import UIKit
import UserNotifications

class ZoneManager {
    let locationManager: CLLocationManager
    let collector: ZoneManagerCollector
    let processor: ZoneManagerProcessor
    let regionFilter: ZoneManagerRegionFilter
    let zoneEventOutbox: ZoneEventOutbox
    private(set) var zones: [AppZone]

    private var observationToken: AnyDatabaseCancellable?
    private let syncExecutor: (@escaping () -> Void) -> Void
    private static let regionSyncQueue = DispatchQueue(label: "zone-manager-region-sync", qos: .utility)
    private var drainingZoneEventIDs = Set<UUID>()
    private var reconcilingZoneEventIDs = Set<UUID>()
    private var confirmedZoneEventIDs = Set<UUID>()
    private var zoneEventRetryAttempt = 0
    private var zoneEventRetryWorkItem: DispatchWorkItem?
    private let zoneEventRetryDelay: (Int) -> TimeInterval

    init(
        locationManager: CLLocationManager = .init(),
        collector: ZoneManagerCollector = ZoneManagerCollectorImpl(),
        processor: ZoneManagerProcessor = ZoneManagerProcessorImpl(),
        regionFilter: ZoneManagerRegionFilter = ZoneManagerRegionFilterImpl(),
        syncExecutor: @escaping (@escaping () -> Void) -> Void = { work in
            ZoneManager.regionSyncQueue.async(execute: work)
        },
        zoneEventOutbox: ZoneEventOutbox = AtomicFileZoneEventOutbox(),
        zoneEventRetryDelay: @escaping (Int) -> TimeInterval = { attempt in
            min(pow(2, Double(max(0, attempt - 1))), 30)
        }
    ) {
        self.locationManager = locationManager
        self.collector = collector
        self.processor = processor
        self.regionFilter = regionFilter
        self.syncExecutor = syncExecutor
        self.zoneEventOutbox = zoneEventOutbox
        self.zoneEventRetryDelay = zoneEventRetryDelay
        self.zones = AppZone.trackedZones()

        self.collector.delegate = self
        self.processor.delegate = self

        log(state: .initialize)

        updateLocationManager(isInitial: true)
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingZoneEvents()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(locationSettingDidChange),
            name: SettingsStore.locationRelatedSettingDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    deinit {
        zoneEventRetryWorkItem?.cancel()
        observationToken?.cancel()
        NotificationCenter.default.removeObserver(self)
        Current.Log.info("going away")
    }

    @objc private func locationSettingDidChange() {
        updateLocationManager(isInitial: false)
    }

    @objc func applicationDidBecomeActive() {
        collector.stopBackgroundBeaconMonitoring(manager: locationManager)
        guard Current.settingsStore.locationSources.zone else { return }

        flushPendingZoneEvents()

        collector.startForegroundBeaconScanning(
            in: locationManager.monitoredRegions,
            manager: locationManager
        )
    }

    @objc func applicationWillResignActive() {
        collector.stopForegroundBeaconScanning(manager: locationManager)
        guard Current.settingsStore.locationSources.zone else { return }
        collector.startBackgroundBeaconMonitoring(
            in: locationManager.monitoredRegions,
            manager: locationManager
        )
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
            let observation = ValueObservation.tracking { db in
                try AppZone
                    .filter(Column(DatabaseTables.AppZone.trackingEnabled.rawValue) == true)
                    .fetchAll(db)
            }
            // .immediate delivers the initial zones synchronously (we are on the
            // main queue), matching the previous Realm behavior of monitoring
            // regions as soon as the manager is created.
            observationToken = observation.start(
                in: Current.database(),
                scheduling: .immediate,
                onError: { error in
                    Current.Log.error("couldn't sync zones: \(error)")
                },
                onChange: { [weak self] zones in
                    guard let self else { return }
                    self.zones = zones
                    sync(zones: AnyCollection(zones))
                }
            )
        } else {
            sync(zones: AnyCollection(zones))
        }
    }

    private func log(state: ZoneManagerState) {
        Current.Log.info(state)
    }

    private func perform(event: ZoneManagerEvent) {
        // although technically the processor also does this, it does it after some async processing.
        // let's be very confident that we're not going to miss out on an update due to being suspended,
        // so the background task starts before any asynchronous work (like fetching the current SSID).
        let performPromise = Current.backgroundTask(withName: BackgroundTask.zoneManagerPerformEvent.rawValue) { _ in
            processor.perform(event: event)
        }.get { [weak self] _ in
            // a location change means we should consider changing our monitored regions
            // ^ not tap for this side effect because we don't want to do this on failure
            guard let self else { return }
            sync(zones: AnyCollection(zones))
        }

        Guarantee<String?> { seal in
            Task {
                await seal(Current.connectivity.currentWiFiSSID())
            }
        }.done { currentSSID in
            let logPayload: [String: String] = [
                "start_ssid": currentSSID ?? "none",
                "event": event.description,
            ]

            performPromise.done {
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Updated location",
                    type: .locationUpdate,
                    payload: logPayload
                ))
            }.catch { error in
                Current.Log.error("ZoneManagerPerformEvent background task error for \(event): \(error)")

                var updatedPayload = logPayload
                updatedPayload["error"] = String(describing: error)

                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Didn't update: \(error.localizedDescription)",
                    type: .locationUpdate,
                    payload: updatedPayload
                ))

                Current.notificationDispatcher.send(.init(
                    id: .debug,
                    title: "DEBUG: Failed to perform ZoneManager event",
                    body: "Event: \(event.eventType.description), error: \(error.localizedDescription)"
                ))
            }
        }
    }

    private func fire(event: ZoneManagerEvent) {
        if case .locationChange = event.eventType {
            flushPendingZoneEvents()
            return
        }

        guard let zone = event.associatedZone else {
            // notifyBeaconFirePreconditionFailure(event: event, reason: "Zone missing")
            return
        }
        guard let server = Current.servers.server(forServerIdentifier: zone.serverIdentifier) else {
            // notifyBeaconFirePreconditionFailure(event: event, reason: "Server missing")
            return
        }

        switch event.eventType {
        case let .region(region, state):
            guard let api = Current.api(for: server) else {
                Current.Log.error("No API available to fire ZoneManager event, server: \(server)")
                // notifyBeaconFirePreconditionFailure(event: event, reason: "API missing")
                return
            }
            let eventInfo = api.zoneStateEvent(region: region, state: state, zone: zone)
            enqueueZoneEvent(
                serverIdentifier: server.identifier.rawValue,
                eventType: eventInfo.eventType,
                eventData: eventInfo.eventData,
                isBeacon: region is CLBeaconRegion
            )
        case .locationChange:
            break
        }
    }

    private func enqueueZoneEvent(
        serverIdentifier: String,
        eventType: String,
        eventData: [String: Any],
        isBeacon: Bool
    ) {
        do {
            let pending = try PendingZoneEvent(
                serverIdentifier: serverIdentifier,
                eventType: eventType,
                eventData: eventData,
                isBeacon: isBeacon
            )
            // Persist before any asynchronous URL resolution or URLSession task creation.
            // iOS may suspend us at either boundary; the next wake can then resume delivery.
            try zoneEventOutbox.append(pending)
            logBeaconDeliveryStage("outbox_persisted", pendingEvent: pending)
            /* DEBUG TESTING ONLY
             if pending.isBeacon == true {
                 sendBeaconStageNotification(
                     id: .beaconEventPersisted,
                     title: "Beacon event persisted to outbox",
                     pendingEvent: pending
                 )
             }
             */
            flushPendingZoneEvents()
        } catch {
            let message = "Failed to persist ZoneManager event before delivery: \(error.localizedDescription)"
            Current.Log.error(message)
            Current.clientEventStore.addEvent(.init(text: message, type: .locationUpdate))
            /* DEBUG TESTING ONLY
             if isBeacon {
                 sendBeaconDeliveryNotification(
                     id: .beaconEventQueued,
                     title: "Beacon event could not be persisted",
                     eventType: eventType,
                     eventData: eventData,
                     detail: error.localizedDescription
                 )
             }
             */
        }
    }

    private func startZoneEvent(
        api: HomeAssistantAPI,
        pendingEvent: PendingZoneEvent,
        eventData: [String: Any]
    ) -> Bool {
        let startResult = api.startPersistentEvent(
            eventType: pendingEvent.eventType,
            eventData: eventData,
            eventIdentifier: pendingEvent.id
        )

        guard case let .success(delivery) = startResult else {
            if case let .failure(error) = startResult {
                let message = "Failed to start ZoneManager background upload; queued for retry: " +
                    error.localizedDescription
                Current.Log.error(message)
                Current.clientEventStore.addEvent(.init(text: message, type: .locationUpdate))
                /* DEBUG TESTING ONLY
                 if pendingEvent.isBeacon == true {
                     sendBeaconDeliveryNotification(
                         id: .beaconEventQueued,
                         title: "Beacon event is waiting for Home Assistant",
                         eventType: pendingEvent.eventType,
                         eventData: eventData,
                         detail: "Upload did not start; retry scheduled"
                     )
                 }
                 */
            }
            clearDeliveryStarted(for: pendingEvent)
            scheduleZoneEventRetry()
            return false
        }

        attach(delivery: delivery, to: pendingEvent)
        return true
    }

    private func handleZoneEventResult(
        _ result: Result<Void>,
        pendingEvent: PendingZoneEvent
    ) {
        drainingZoneEventIDs.remove(pendingEvent.id)

        switch result {
        case .fulfilled:
            zoneEventRetryAttempt = 0
            logBeaconDeliveryStage("webhook_confirmed", pendingEvent: pendingEvent)
            confirmedZoneEventIDs.insert(pendingEvent.id)
            removeConfirmedZoneEvent(pendingEvent)
            Current.Log.info("Fired ZoneManager event")
        /* DEBUG TESTING ONLY
         if pendingEvent.isBeacon == true {
             sendBeaconDeliveryNotification(
                 id: .beaconEventDelivered,
                 title: "Beacon event delivered to Home Assistant",
                 eventType: pendingEvent.eventType,
                 eventData: pendingEvent.decodedEventData ?? [:]
             )
         }
         */
        case let .rejected(error):
            logBeaconDeliveryStage(
                "webhook_failed",
                pendingEvent: pendingEvent,
                detail: error.localizedDescription
            )
            let message = "Failed to fire ZoneManager event; queued for retry: \(error.localizedDescription)"
            Current.Log.error(message)
            Current.clientEventStore.addEvent(.init(text: message, type: .locationUpdate))
            clearDeliveryStarted(for: pendingEvent)
            /* DEBUG TESTING ONLY
             if pendingEvent.isBeacon == true {
                 sendBeaconDeliveryNotification(
                     id: .beaconEventQueued,
                     title: "Beacon event is waiting for Home Assistant",
                     eventType: pendingEvent.eventType,
                     eventData: pendingEvent.decodedEventData ?? [:],
                     detail: "Delivery failed; retry scheduled"
                 )
             }
             */
            scheduleZoneEventRetry()
        }
    }

    private func flushPendingZoneEvents() {
        guard let pendingEvents = loadPendingZoneEvents() else { return }
        guard !pendingEvents.isEmpty else {
            zoneEventRetryAttempt = 0
            zoneEventRetryWorkItem?.cancel()
            zoneEventRetryWorkItem = nil
            return
        }
        guard drainingZoneEventIDs.isEmpty, reconcilingZoneEventIDs.isEmpty else { return }

        drainPendingZoneEvents(pendingEvents)
    }

    private func loadPendingZoneEvents() -> [PendingZoneEvent]? {
        do {
            return try zoneEventOutbox.pendingEvents()
        } catch {
            logZoneEventOutboxFailure("read", error: error)
            scheduleZoneEventRetry()
            return nil
        }
    }

    private func drainPendingZoneEvents(_ pendingEvents: [PendingZoneEvent]) {
        guard let pending = pendingEvents.first else {
            flushPendingZoneEvents()
            return
        }
        if confirmedZoneEventIDs.contains(pending.id) {
            removeConfirmedZoneEvent(pending)
            return
        }
        guard let eventData = pending.decodedEventData else {
            removeUnreadableZoneEvent(pending, remainingEvents: Array(pendingEvents.dropFirst()))
            return
        }
        guard let server = Current.servers.server(forServerIdentifier: pending.serverIdentifier) else {
            logZoneEventDrainBlocked(pending, reason: "Server is unavailable")
            scheduleZoneEventRetry()
            return
        }
        guard let api = Current.api(for: server) else {
            logZoneEventDrainBlocked(pending, reason: "Home Assistant API is unavailable")
            scheduleZoneEventRetry()
            return
        }
        if pending.deliveryStartedAt != nil {
            reconcileZoneEvent(api: api, pendingEvent: pending)
            return
        }

        do {
            try zoneEventOutbox.markDeliveryStarted(id: pending.id, at: Current.date())
            _ = startZoneEvent(api: api, pendingEvent: pending, eventData: eventData)
        } catch {
            logZoneEventOutboxFailure("mark delivery started", error: error)
            scheduleZoneEventRetry()
        }
    }

    private func removeUnreadableZoneEvent(
        _ pendingEvent: PendingZoneEvent,
        remainingEvents: [PendingZoneEvent]
    ) {
        logZoneEventDrainBlocked(pendingEvent, reason: "Event data is unreadable")
        do {
            try zoneEventOutbox.remove(id: pendingEvent.id)
            drainPendingZoneEvents(remainingEvents)
        } catch {
            logZoneEventOutboxFailure("remove unreadable event", error: error)
            scheduleZoneEventRetry()
        }
    }

    private func attach(delivery: Task<Void, Error>, to pendingEvent: PendingZoneEvent) {
        drainingZoneEventIDs.insert(pendingEvent.id)
        zoneEventRetryWorkItem?.cancel()
        zoneEventRetryWorkItem = nil
        logBeaconDeliveryStage("background_upload_started", pendingEvent: pendingEvent)
        if pendingEvent.isBeacon == true {
            scheduleBeaconUploadWatchdog(for: pendingEvent)
        }

        Task { [weak self] in
            let result = await delivery.result
            await MainActor.run {
                switch result {
                case .success:
                    self?.handleZoneEventResult(.fulfilled(()), pendingEvent: pendingEvent)
                case let .failure(error):
                    self?.handleZoneEventResult(.rejected(error), pendingEvent: pendingEvent)
                }
            }
        }
    }

    private func reconcileZoneEvent(api: HomeAssistantAPI, pendingEvent: PendingZoneEvent) {
        guard reconcilingZoneEventIDs.insert(pendingEvent.id).inserted else { return }

        Task { [weak self] in
            let state = await api.reconcilePersistentEvent(eventIdentifier: pendingEvent.id)
            await MainActor.run {
                guard let self else { return }
                reconcilingZoneEventIDs.remove(pendingEvent.id)
                switch state {
                case let .running(delivery):
                    attach(delivery: delivery, to: pendingEvent)
                case let .completed(result):
                    switch result {
                    case .success:
                        handleZoneEventResult(.fulfilled(()), pendingEvent: pendingEvent)
                    case let .failure(error):
                        handleZoneEventResult(.rejected(error), pendingEvent: pendingEvent)
                    }
                case .absent:
                    if clearDeliveryStarted(for: pendingEvent) {
                        flushPendingZoneEvents()
                    } else {
                        scheduleZoneEventRetry()
                    }
                }
            }
        }
    }

    @discardableResult
    private func clearDeliveryStarted(for pendingEvent: PendingZoneEvent) -> Bool {
        do {
            try zoneEventOutbox.clearDeliveryStarted(id: pendingEvent.id)
            return true
        } catch {
            logZoneEventOutboxFailure("clear delivery state", error: error)
            return false
        }
    }

    private func removeConfirmedZoneEvent(_ pendingEvent: PendingZoneEvent) {
        do {
            try zoneEventOutbox.remove(id: pendingEvent.id)
            confirmedZoneEventIDs.remove(pendingEvent.id)
            flushPendingZoneEvents()
        } catch {
            logZoneEventOutboxFailure("remove confirmed event", error: error)
            scheduleZoneEventRetry()
        }
    }

    private func logZoneEventOutboxFailure(_ operation: String, error: Error) {
        let message = "ZoneManager outbox failed to \(operation): \(error.localizedDescription)"
        Current.Log.error(message)
        Current.clientEventStore.addEvent(.init(text: message, type: .locationUpdate))
    }

    private func scheduleZoneEventRetry() {
        guard zoneEventRetryWorkItem == nil else { return }
        zoneEventRetryAttempt += 1
        let delay = zoneEventRetryDelay(zoneEventRetryAttempt)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            zoneEventRetryWorkItem = nil
            flushPendingZoneEvents()
        }
        zoneEventRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func logZoneEventDrainBlocked(_ pendingEvent: PendingZoneEvent, reason: String) {
        let message = "ZoneManager outbox drain blocked: \(reason)"
        Current.Log.error(message)
        Current.clientEventStore.addEvent(.init(text: message, type: .locationUpdate))
        guard pendingEvent.isBeacon == true else { return }
        /* DEBUG TESTING ONLY
         sendBeaconStageNotification(
             id: .beaconEventQueued,
             title: "Beacon event is waiting for Home Assistant",
             pendingEvent: pendingEvent,
             detail: reason
         )
         */
    }

    // DEBUG TESTING ONLY: call sites are disabled for production while retaining the diagnostic helpers.
    private func sendLocalBeaconNotification(for event: ZoneManagerEvent) {
        guard case let .region(region, state) = event.eventType,
              region is CLBeaconRegion,
              let zone = event.associatedZone else { return }

        let notification: LocalNotificationDispatcher.Notification
        switch state {
        case .inside:
            let diagnostic = event.beaconDiagnostic.map {
                "\(beaconDiagnosticTimestamp()) · \($0.isAppActive ? "foreground" : "background") · " +
                    "\($0.proximity) · RSSI \($0.rssi)"
            } ?? "\(beaconDiagnosticTimestamp()) · detected locally"
            notification = .init(
                id: .beaconDetectedLocally,
                title: "\(zone.name): Beacon detected locally",
                body: diagnostic,
                sound: .default
            )
        case .outside:
            let appState = UIApplication.shared.applicationState == .active ? "foreground" : "background"
            notification = .init(
                id: .beaconExitedLocally,
                title: "\(zone.name): Beacon exited locally",
                body: "\(beaconDiagnosticTimestamp()) · \(appState) · no longer detected locally",
                sound: .default
            )
        case .unknown:
            return
        }

        Current.notificationDispatcher.send(notification)
    }

    // DEBUG TESTING ONLY: the notification methods in this block expose the physical Beacon delivery stages.
    // Their call sites are disabled for production and can be re-enabled for physical diagnostics.
    private func notifyBeaconFirePreconditionFailure(event: ZoneManagerEvent, reason: String) {
        guard case let .region(region, state) = event.eventType,
              region is CLBeaconRegion else { return }

        let action = state == .inside ? "Entry" : "Exit"
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Beacon delivery: preflight_failed",
            type: .networkRequest,
            payload: [
                "stage": "preflight_failed",
                "region": region.identifier,
                "state": String(describing: state),
                "reason": reason,
                "recorded_at": ISO8601DateFormatter().string(from: Current.date()),
            ]
        ))
        Current.notificationDispatcher.send(.init(
            id: .beaconEventPreflightFailed,
            title: "Beacon event stopped before outbox persistence",
            body: "\(action) · \(reason) · \(beaconDiagnosticTimestamp())"
        ))
    }

    private func sendBeaconStageNotification(
        id: NotificationIdentifier,
        title: String,
        pendingEvent: PendingZoneEvent,
        detail: String? = nil
    ) {
        guard pendingEvent.isBeacon == true else { return }
        let action = pendingEvent.eventType == "ios.zone_entered" ? "Entry" : "Exit"
        let shortID = String(pendingEvent.id.uuidString.prefix(8))
        let body = [action, shortID, beaconDiagnosticTimestamp(), detail].compactMap { $0 }
            .joined(separator: " · ")
        Current.notificationDispatcher.send(.init(id: id, title: title, body: body))
    }

    private func scheduleBeaconUploadWatchdog(for pendingEvent: PendingZoneEvent) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self,
                  drainingZoneEventIDs.contains(pendingEvent.id),
                  (try? self.zoneEventOutbox.pendingEvents())?.contains(where: { $0.id == pendingEvent.id }) == true else { return }

            logBeaconDeliveryStage(
                "webhook_stalled",
                pendingEvent: pendingEvent,
                detail: "No completion after 15 seconds"
            )
            /* DEBUG TESTING ONLY
             self.sendBeaconStageNotification(
                 id: .beaconEventUploadStalled,
                 title: "Beacon upload has no response",
                 pendingEvent: pendingEvent,
                 detail: ">15 seconds"
             )
             */
        }
    }

    private func logBeaconDeliveryStage(
        _ stage: String,
        pendingEvent: PendingZoneEvent,
        detail: String? = nil
    ) {
        guard pendingEvent.isBeacon == true else { return }
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Beacon delivery: \(stage)",
            type: .networkRequest,
            payload: [
                "stage": stage,
                "event_id": pendingEvent.id.uuidString,
                "event_type": pendingEvent.eventType,
                "created_at": ISO8601DateFormatter().string(from: pendingEvent.createdAt),
                "recorded_at": ISO8601DateFormatter().string(from: Current.date()),
                "detail": detail ?? "",
            ]
        ))
    }

    private func beaconDiagnosticTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    private func sendBeaconDeliveryNotification(
        id: NotificationIdentifier,
        title: String,
        eventType: String,
        eventData: [String: Any],
        detail: String? = nil
    ) {
        guard eventType == "ios.zone_entered" || eventType == "ios.zone_exited",
              let zone = eventData["zone"] as? String else { return }

        let action = eventType == "ios.zone_entered" ? "Entry" : "Exit"
        let body = ["\(action): \(zone)", detail].compactMap { $0 }.joined(separator: " · ")
        Current.notificationDispatcher.send(.init(
            id: id,
            title: title,
            body: body
        ))
    }

    private func sync(zones: AnyCollection<AppZone>) {
        syncExecutor { [weak self] in
            self?.syncNow(zones: zones)
        }
    }

    /// Runs on the sync executor: `monitoredRegions` and `location` perform synchronous XPC to
    /// locationd, which hangs the main thread when the daemon is slow to reply (this was the app's
    /// top field hang), so they must be read off the main thread.
    private func syncNow(zones: AnyCollection<AppZone>) {
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

        // Applied on the main thread because the collector (and its ignore-next-state bookkeeping)
        // is only ever touched from there; synchronously, so the next queued sync's reads observe
        // these mutations and can't re-add the same regions.
        let expectedRegions = Set(expected.map(\.region))
        Self.runOnMain { [self] in
            // process removals before additions
            // this is important because the system is focused on identifier
            for region in needsRemoval.map(\.region) {
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Ending monitoring \(region.identifier)",
                    type: .locationUpdate,
                    payload: [
                        "region": String(describing: region),
                    ]
                ))
                locationManager.stopMonitoring(for: region)
            }

            for region in needsAddition.map(\.region) {
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Initially monitoring \(region.identifier)",
                    type: .locationUpdate,
                    payload: [
                        "region": String(describing: region),
                    ]
                ))

                collector.ignoreNextState(for: region)
                locationManager.startMonitoring(for: region)
            }

            if UIApplication.shared.applicationState == .active {
                collector.stopBackgroundBeaconMonitoring(manager: locationManager)
                collector.startForegroundBeaconScanning(in: expectedRegions, manager: locationManager)
            } else {
                collector.stopForegroundBeaconScanning(manager: locationManager)
                collector.startBackgroundBeaconMonitoring(in: expectedRegions, manager: locationManager)
            }
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

    private static func runOnMain(_ work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}

extension ZoneManager: ZoneManagerCollectorDelegate {
    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState) {
        log(state: state)
    }

    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent) {
        // DEBUG TESTING ONLY: immediate proof that iOS accepted the Beacon transition. Disable for the final PR by
        // commenting out this call; retain the helper above for future diagnostics.
        // sendLocalBeaconNotification(for: event)
        if case let .region(region, state) = event.eventType, region is CLBeaconRegion {
            Current.clientEventStore.addEvent(ClientEvent(
                text: "Beacon delivery: accepted_sample",
                type: .locationUpdate,
                payload: [
                    "stage": "accepted_sample",
                    "region": region.identifier,
                    "state": String(describing: state),
                    "recorded_at": ISO8601DateFormatter().string(from: Current.date()),
                ]
            ))
        }
        fire(event: event)
        perform(event: event)
    }
}

extension ZoneManager: ZoneManagerProcessorDelegate {
    func processor(_ processor: ZoneManagerProcessor, didLog state: ZoneManagerState) {
        log(state: state)
    }
}
