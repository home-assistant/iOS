import Foundation
import HAKit
import Shared

final class CarPlayQuickAccessViewModel {
    /// What this template renders: the Quick Access list itself, or a single Quick Access folder
    /// promoted to its own tab.
    enum Source {
        case quickAccess
        case folder(folderId: String)
    }

    weak var templateProvider: CarPlayQuickAccessTemplate?
    let source: Source

    init(source: Source = .quickAccess) {
        self.source = source
    }

    func update() {
        do {
            if let config = try CarPlayConfig.config() {
                templateProvider?.updateList(
                    for: filterItems(items(from: config)),
                    layout: config.resolvedQuickAccessLayout,
                    showAddEditButtons: showAddEditButtons(config: config)
                )
            } else {
                templateProvider?.updateList(
                    for: [],
                    layout: .grid,
                    showAddEditButtons: showAddEditButtons(config: nil)
                )
            }
        } catch {
            Current.Log.error("Failed to access CarPlay configuration, error: \(error.localizedDescription)")
            templateProvider?.updateList(
                for: [],
                layout: .grid,
                showAddEditButtons: showAddEditButtons(config: nil)
            )
        }
    }

    private func items(from config: CarPlayConfig) -> [MagicItem] {
        switch source {
        case .quickAccess:
            return config.quickAccessItems
        case let .folder(folderId):
            // Folders can't nest in CarPlay; drop any stray nested folders defensively.
            return (config.folder(withId: folderId)?.items ?? []).filter { $0.type != .folder }
        }
    }

    private func showAddEditButtons(config: CarPlayConfig?) -> Bool {
        switch source {
        case .quickAccess:
            return config?.resolvedShowAddEditButtons ?? true
        case .folder:
            // Folder contents are managed from the iPhone app only.
            return false
        }
    }

    private func filterItems(_ items: [MagicItem]) -> [MagicItem] {
        items.compactMap { item in
            guard item.type != .unsupported else { return nil }
            if item.type == .folder {
                var item = item
                item.items = filterItems(item.items ?? [])
                return item
            }
            if #available(iOS 26.4, *) {
                return item
            } else {
                return (item.type == .assistPipeline || item.type == .assistPrompt) ? nil : item
            }
        }
    }
}
