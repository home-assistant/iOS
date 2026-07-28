import Foundation
import Shared

extension CarPlayQuickAccessTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayQuickAccessTemplate(viewModel: .init())
    }

    /// Builds a tab rendering the given Quick Access folder's items.
    static func buildFolderTab(folder: MagicItem) -> any CarPlayTemplateProvider {
        CarPlayQuickAccessTemplate(
            viewModel: .init(source: .folder(folderId: folder.id)),
            folder: folder
        )
    }
}
