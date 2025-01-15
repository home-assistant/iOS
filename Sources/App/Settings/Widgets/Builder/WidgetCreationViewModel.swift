import Foundation
import Shared

final class WidgetCreationViewModel: ObservableObject {
    @Published var showAddItem = false
    @Published var widget = CustomWidget(name: "", items: [])

    private let infoProvider = Current.magicItemProvider()

    func load() {
        infoProvider.loadInformation { _ in
            Current.Log.info("Loaded information for custom widget creation")
        }
    }

    func save() {
        // Save
    }

    func magicItemInfo(for item: MagicItem) -> MagicItem.Info? {
        infoProvider.getInfo(for: item)
    }

    func addItem(_ item: MagicItem) {
        widget.items.append(item)
    }

    func updateItem(_ item: MagicItem) {
        if let indexToUpdate = widget.items
            .firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            widget.items.remove(at: indexToUpdate)
            widget.items.insert(item, at: indexToUpdate)
        }
    }

    func deleteItem(at offsets: IndexSet) {
        widget.items.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        widget.items.move(fromOffsets: source, toOffset: destination)
    }
}
