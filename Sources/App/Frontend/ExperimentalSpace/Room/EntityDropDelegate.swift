import HAKit
import SwiftUI

@available(iOS 26.0, *)
struct EntityDropDelegate: DropDelegate {
    let entity: HAEntity
    let entities: [HAEntity]
    @Binding var draggedEntity: String?
    let roomId: String
    let viewModel: HomeViewModel

    func performDrop(info: DropInfo) -> Bool {
        draggedEntity = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedEntity,
              draggedEntity != entity.entityId else { return }

        let from = entities.firstIndex { $0.entityId == draggedEntity }
        let to = entities.firstIndex { $0.entityId == entity.entityId }

        guard let from, let to else { return }

        var currentOrder = viewModel.getEntityOrder(for: roomId)

        if currentOrder.isEmpty {
            // Initialize order if empty
            currentOrder = entities.map(\.entityId)
        }

        // Find indices in the order array
        guard let fromIndex = currentOrder.firstIndex(of: draggedEntity),
              let toIndex = currentOrder.firstIndex(of: entity.entityId) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            viewModel.saveEntityOrder(for: roomId, order: currentOrder)
        }
    }
}
