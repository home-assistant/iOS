import Foundation
import Shared
import WidgetKit

final class WidgetBuilderViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var widgets: [CustomWidget] = []

    func reloadWidgets() {
        isLoading = true
        WidgetCenter.shared.reloadAllTimelines()

        // Delay to give some sense of execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isLoading = false
        }
    }

    func loadWidgets() {
        do {
            widgets = try CustomWidget.widgets()?.sorted(by: { $0.name < $1.name }) ?? []
        } catch {
            Current.Log.error("Failed to load widgets: \(error)")
        }
    }

    func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            do {
                _ = try Current.database.write { db in
                    try widgets[index].delete(db)
                }
                loadWidgets()
            } catch {
                Current.Log.error("Failed to delete custom widget, error: \(error.localizedDescription)")
            }
        }
    }

    func deleteAllWidgets() {
        do {
            _ = try Current.database.write { db in
                try CustomWidget.deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to delete all widgets: \(error)")
        }
        loadWidgets()
    }
}
