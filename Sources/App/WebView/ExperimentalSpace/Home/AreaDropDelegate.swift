import SwiftUI

@available(iOS 26.0, *)
struct AreaDropDelegate: DropDelegate {
    let area: HomeViewModel.RoomSection
    let areas: [HomeViewModel.RoomSection]
    @Binding var draggedArea: String?
    let viewModel: HomeViewModel

    func performDrop(info: DropInfo) -> Bool {
        draggedArea = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedArea,
              draggedArea != area.id else { return }

        let from = areas.firstIndex { $0.id == draggedArea }
        let to = areas.firstIndex { $0.id == area.id }

        guard let from, let to else { return }

        var currentOrder = viewModel.getAreaOrder()

        if currentOrder.isEmpty {
            // Initialize order if empty
            currentOrder = areas.map(\.id)
        }

        // Find indices in the order array
        guard let fromIndex = currentOrder.firstIndex(of: draggedArea),
              let toIndex = currentOrder.firstIndex(of: area.id) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            viewModel.saveAreaOrder(currentOrder)
        }
    }
}
