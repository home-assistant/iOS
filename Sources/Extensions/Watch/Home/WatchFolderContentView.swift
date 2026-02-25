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
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.visible, for: .navigationBar)
            } else if #available(watchOS 9.0, *) {
                view.toolbar(.visible, for: .navigationBar)
            } else {
                view.navigationBarHidden(false)
            }
        }
    }
}
