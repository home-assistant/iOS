import SwiftUI

/// Reorders sidebar rows live while a row is dragged over them and commits the new order on drop.
/// Attached to every row (with its id) and to the list container (with `targetItemId == nil`) so a
/// drop between rows still commits.
struct MacSidebarReorderDropDelegate: DropDelegate {
    let targetItemId: String?
    @Binding var draggingItemId: String?
    let move: (_ draggedId: String, _ targetId: String) -> Void
    let commit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingItemId, let targetItemId, draggingItemId != targetItemId else { return }
        move(draggingItemId, targetItemId)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggingItemId != nil else { return false }
        draggingItemId = nil
        commit()
        return true
    }
}
