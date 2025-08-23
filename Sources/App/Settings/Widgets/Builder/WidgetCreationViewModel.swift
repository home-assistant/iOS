import Foundation
import Shared

final class WidgetCreationViewModel: ObservableObject {
    @Published var showAddItem = false
    @Published var shouldDismiss = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var widget: CustomWidget

    private let infoProvider = Current.magicItemProvider()

    init(widget: CustomWidget) {
        self.widget = widget
    }

    func load() {
        infoProvider.loadInformation { _ in
            Current.Log.info("Loaded information for custom widget creation")
        }
    }

    func save() {
        guard !widget.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !widget.items.isEmpty else {
            errorMessage = "Make sure you have set a name and at least one item for the widget."
            showError = true
            return
        }
        do {
            try Current.database().write { db in
                try widget.insert(db, onConflict: .replace)
            }
            DataWidgetsUpdater.update()
            shouldDismiss = true
        } catch {
            Current.Log.error("Failed to insert/update custom widget, error: \(error.localizedDescription)")

            errorMessage = "Failed to insert/update custom widget, error: \(error.localizedDescription)"
            showError = true
        }
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
