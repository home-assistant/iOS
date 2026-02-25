import Shared
import SwiftUI

struct WatchFolderContentView: View {
    let folderId: String
    @ObservedObject var viewModel: WatchHomeViewModel

    private var folder: MagicItem? {
        viewModel.watchConfig.items.first(where: { $0.type == .folder && $0.id == folderId })
    }

    var body: some View {
        List {
            ForEach(folder?.items ?? [], id: \.viewIdentity) { item in
                WatchMagicViewRow(
                    item: item,
                    itemInfo: viewModel.info(for: item)
                )
            }
        }
        .navigationTitle(folder?.displayText ?? L10n.Watch.Configuration.Folder.defaultName)
    }
}
