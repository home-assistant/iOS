#if !os(watchOS)
import SwiftUI

/// Holds a drag while it is happening: which room is being moved, and the order the cards are shown
/// in until it is dropped.
///
/// The order only becomes real when the drag ends — while it is in the air this is what the grid
/// draws, so the rooms part and close around the card the way they do in a list.
@MainActor
public final class HomeAreaReorderCoordinator: ObservableObject {
    /// The area currently in the air, if any.
    @Published public private(set) var draggingAreaId: String?
    /// The order to draw while dragging. `nil` outside a drag: the registry's own order stands.
    @Published public private(set) var liveOrder: [String]?

    /// Called with the new order when a drag ends somewhere it changed something.
    private let onReorder: ([String]) -> Void
    /// Ends a drag that never landed anywhere. `onDrag` reports when a drag begins and a drop
    /// reports where it lands, but nothing reports one being abandoned — without this, a room let go
    /// over the status bar leaves its card faded and the grid in an order nobody asked for.
    private var watchdog: Task<Void, Never>?
    /// Long enough that no real drag is cut short, short enough that a stuck card rights itself
    /// before the user tries again.
    private static let abandonedDragTimeout = Duration.seconds(10)

    public init(onReorder: @escaping ([String]) -> Void) {
        self.onReorder = onReorder
    }

    /// Whether rooms can be dragged at all. A dashboard with nowhere to send the new order cannot.
    public var isEnabled: Bool { true }

    public func begin(dragging areaId: String, in order: [String]) {
        draggingAreaId = areaId
        liveOrder = order
        startWatchdog(original: order)
    }

    /// The dragged card has been pulled over `targetId`: move it there, so the gap follows the
    /// finger.
    public func moveDragged(over targetId: String) {
        guard let draggingAreaId, draggingAreaId != targetId, var order = liveOrder,
              let from = order.firstIndex(of: draggingAreaId),
              let to = order.firstIndex(of: targetId) else {
            return
        }
        order.remove(at: from)
        order.insert(draggingAreaId, at: to)
        liveOrder = order
        startWatchdog(original: order)
    }

    /// A room was dropped onto another one: put it there and hand the order over.
    ///
    /// Computed from the drop rather than from the hovering, because a hover is not guaranteed — a
    /// quick drag, or one synthesised by a test, can carry a room from one card to another without a
    /// single `isTargeted` in between, and the drop is the only event that always arrives.
    public func drop(_ draggedAreaId: String, onto targetAreaId: String, original: [String]) {
        var order = liveOrder ?? original
        if let from = order.firstIndex(of: draggedAreaId), let to = order.firstIndex(of: targetAreaId) {
            order.remove(at: from)
            order.insert(draggedAreaId, at: to)
            liveOrder = order
        }
        drop(original: original)
    }

    /// The drag ended. Hands the order over if it changed, and forgets about the drag either way.
    public func drop(original: [String]) {
        watchdog?.cancel()
        watchdog = nil
        defer {
            draggingAreaId = nil
            liveOrder = nil
        }
        guard let liveOrder, liveOrder != original else {
            return
        }
        onReorder(liveOrder)
    }

    /// Restarts the countdown to giving up on a drag. Every sign of life — the drag beginning, the
    /// card moving over another — pushes it back.
    private func startWatchdog(original: [String]) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.abandonedDragTimeout)
            guard !Task.isCancelled else {
                return
            }
            self?.draggingAreaId = nil
            self?.liveOrder = nil
        }
    }

    /// The order to draw: the one being dragged into, or the registry's.
    public func order(from registryOrder: [String]) -> [String] {
        guard let liveOrder else {
            return registryOrder
        }
        // Anything the registry gained mid-drag is appended rather than dropped.
        return liveOrder + registryOrder.filter { !liveOrder.contains($0) }
    }
}
#endif
