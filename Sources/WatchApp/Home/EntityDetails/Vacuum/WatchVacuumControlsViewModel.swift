import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the vacuum controls screen: start/pause/stop/return to dock plus fan speed.
///
/// Mirrors `WatchCoverControlsViewModel`: state stays fresh through the shared REST polling
/// (`WatchEntityStatePoller`) and commands go out as vacuum service REST calls
/// (`WatchServiceCallSender`). There is nothing continuous to debounce — every control is an
/// explicit button or a single-choice pick.
final class WatchVacuumControlsViewModel: ObservableObject {
    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the values as current.
    @Published private(set) var isStale = false
    /// Areas the vacuum can be told to clean, relayed by the phone (see `loadCleanableAreas`).
    @Published private(set) var cleanableAreas: [VacuumAreaMapping.Area] = []
    /// True while the phone is answering, so the picker can say so rather than looking empty.
    @Published private(set) var isLoadingAreas = false
    /// Area ids picked for the next `clean_area` call, in tap order — the service takes an ordered
    /// list, and the frontend surfaces the same numbering.
    @Published private(set) var selectedAreaIds: [String] = []
    /// Whether the iPhone is close enough to answer right now. Cleaning by area needs it: the
    /// areas come from the entity registry, which Home Assistant serves over WebSocket only — a
    /// transport the watch doesn't have. Without the phone the option is hidden rather than shown
    /// broken.
    @Published private(set) var isPhoneReachable = false

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller
    private var reachabilityObservation: HAWatchConnectivity.ObservationToken?

    deinit {
        if let reachabilityObservation {
            Communicator.shared.reachability.unobserve(reachabilityObservation)
        }
    }

    /// The view model is built inside `StateObject`'s autoclosure by its screen, so creation
    /// (and its poller) is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchEntityStatePoller(entityId: item.id, serverId: item.serverId)
        self.entity = initialEntity
    }

    /// The entity's friendly name, preferred over the configured item name because this screen is
    /// also reached from the area screens, where the entity isn't a configured home item and the
    /// info lookup falls back to the raw entity id.
    var name: String {
        entity?.attributes.friendlyName ?? item.name(info: itemInfo)
    }

    var capabilities: VacuumCapabilities? {
        entity.map(VacuumCapabilities.init(entity:))
    }

    var stateText: String? {
        guard let entity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: entity)
    }

    /// Whether the vacuum is actively cleaning, which flips the primary button to pause.
    var isCleaning: Bool {
        entity?.state == "cleaning"
    }

    var icon: MaterialDesignIcons {
        item.icon(info: itemInfo)
    }

    var iconColor: UIColor {
        if let hex = itemInfo.customization?.iconColor {
            return UIColor(hex: hex)
        }
        return .white
    }

    func startStateUpdates() {
        poller.start { [weak self] snapshot in
            guard let self else { return }
            if let entity = snapshot.entity {
                self.entity = entity
            }
            isStale = snapshot.isStale
        }
        observeReachability()
    }

    func stopStateUpdates() {
        poller.stop()
    }

    /// Track the phone's reachability while the screen is open, so the clean-by-area option
    /// appears and disappears with it instead of being decided once on appear.
    private func observeReachability() {
        isPhoneReachable = Communicator.shared.currentReachability == .immediatelyReachable
        guard reachabilityObservation == nil else { return }
        reachabilityObservation = Communicator.shared.reachability.observe { [weak self] _ in
            DispatchQueue.main.async {
                self?.isPhoneReachable = Communicator.shared.currentReachability == .immediatelyReachable
            }
        }
    }

    // MARK: - Clean areas

    /// Ask the phone which areas this vacuum can clean. The watch can't read the entity registry
    /// itself, so the phone makes the WebSocket call and replies with resolved `{id, name}` pairs.
    func loadCleanableAreas() {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            Current.Log.info("[Watch] Skipping vacuum area fetch, iPhone not immediately reachable")
            isPhoneReachable = false
            return
        }
        isLoadingAreas = true
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.vacuumCleanableAreas.rawValue,
            content: ["entityId": item.id, "serverId": item.serverId],
            reply: { [weak self] message in
                let wireAreas = message.content["areas"] as? [[String: String]] ?? []
                DispatchQueue.main.async {
                    self?.cleanableAreas = wireAreas.compactMap(VacuumAreaMapping.Area.init(wireFormat:))
                    self?.isLoadingAreas = false
                }
            }
        ), errorHandler: { [weak self] error in
            Current.Log.error("[Watch] Failed to request vacuum areas: \(error)")
            DispatchQueue.main.async {
                self?.isLoadingAreas = false
            }
        })
    }

    /// Adds or removes an area from the pending selection, preserving tap order.
    func toggleAreaSelection(_ areaId: String) {
        if let index = selectedAreaIds.firstIndex(of: areaId) {
            selectedAreaIds.remove(at: index)
        } else {
            selectedAreaIds.append(areaId)
        }
    }

    /// 1-based position of an area in the pending selection, or nil when it isn't selected.
    func selectionOrder(of areaId: String) -> Int? {
        selectedAreaIds.firstIndex(of: areaId).map { $0 + 1 }
    }

    /// The service call itself goes out over REST like every other watch command — only the area
    /// list needed the phone.
    func startCleaningSelectedAreas() {
        guard !selectedAreaIds.isEmpty else { return }
        send(service: .cleanArea, data: ["cleaning_area_id": selectedAreaIds])
        selectedAreaIds = []
    }

    // MARK: - Commands

    func start() {
        send(service: .start)
    }

    func pause() {
        send(service: .pause)
    }

    func stop() {
        send(service: .stop)
    }

    func returnToBase() {
        send(service: .returnToBase)
    }

    func locate() {
        send(service: .locate)
    }

    func setFanSpeed(_ speed: String) {
        send(service: .setFanSpeed, data: ["fan_speed": speed])
    }

    // MARK: - Private

    private func send(service: Service, data: [String: Any] = [:]) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }) else {
            Current.Log.error("Server \(item.serverId) not synced to the watch for vacuum controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WKInterfaceDevice.current().play(.click)
        WatchServiceCallSender.send(
            domain: .vacuum,
            service: service,
            entityId: item.id,
            data: data,
            server: server
        ) { [weak poller] success in
            if success {
                // Reflect the executed command quickly instead of waiting a full poll interval.
                poller?.refresh(after: 1)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
