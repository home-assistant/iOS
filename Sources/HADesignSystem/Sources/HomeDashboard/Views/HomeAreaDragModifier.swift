#if !os(watchOS)
import SwiftUI

/// Makes a room's card draggable and a drop target for another one, which together are how the rooms
/// are reordered.
///
/// Applied to every card in a section and doing nothing for the ones that are not rooms: a heading or
/// a tile has no place in the order, and nothing should happen when a room is dragged over one.
public struct HomeAreaDragModifier: ViewModifier {
    @EnvironmentObject private var reorder: HomeAreaReorderCoordinator

    private let areaId: String?
    private let areaOrder: [String]

    public init(areaId: String?, areaOrder: [String]) {
        self.areaId = areaId
        self.areaOrder = areaOrder
    }

    public func body(content: Content) -> some View {
        if let areaId, areaOrder.count > 1 {
            content
                // The card being dragged fades where it was, so the gap it leaves is visible.
                .opacity(reorder.draggingAreaId == areaId ? 0.35 : 1)
                .onDrag {
                    // `onDrag` rather than `draggable`: it is the only one that says *when* a drag
                    // starts, and the coordinator has to know which room is in the air before the
                    // first card is dragged over.
                    reorder.begin(dragging: areaId, in: areaOrder)
                    return NSItemProvider(object: areaId as NSString)
                }
                .dropDestination(for: String.self) { dropped, _ in
                    // The dragged room comes out of the drop itself when it can, so a drag that
                    // never hovered still lands where it was let go.
                    guard let dragged = dropped.first ?? reorder.draggingAreaId else {
                        return false
                    }
                    withAnimation(.snappy) {
                        reorder.drop(dragged, onto: areaId, original: areaOrder)
                    }
                    return true
                } isTargeted: { isTargeted in
                    guard isTargeted else {
                        return
                    }
                    withAnimation(.snappy) {
                        reorder.moveDragged(over: areaId)
                    }
                }
        } else {
            content
        }
    }
}
#endif
