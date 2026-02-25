import Shared
import SwiftUI

struct WatchFolderContentView: View {
    let folder: MagicItem
    let viewModel: WatchHomeViewModel

    var body: some View {
        List {
            ForEach(folder.items ?? [], id: \.serverUniqueId) { item in
                WatchMagicViewRow(
                    item: item,
                    itemInfo: viewModel.info(for: item)
                )
            }
        }
        .navigationTitle(folder.displayText ?? L10n.Watch.Configuration.Folder.defaultName)
    }
}
