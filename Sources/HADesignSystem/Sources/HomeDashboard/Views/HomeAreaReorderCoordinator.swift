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

    public init(onReorder: @escaping ([String]) -> Void) {
        self.onReorder = onReorder
    }

    /// Whether rooms can be dragged at all. A dashboard with nowhere to send the new order cannot.
    public var isEnabled: Bool { true }

    public func begin(dragging areaId: String, in order: [String]) {
        draggingAreaId = areaId
        liveOrder = order
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
    }

    /// The drag ended. Hands the order over if it changed, and forgets about the drag either way.
    public func drop(original: [String]) {
        defer {
            draggingAreaId = nil
            liveOrder = nil
        }
        guard let liveOrder, liveOrder != original else {
            return
        }
        onReorder(liveOrder)
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
