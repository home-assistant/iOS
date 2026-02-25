import SFSafeSymbols
import Shared
import SwiftUI

struct WatchFolderContentView: View {
    let folderId: String
    @ObservedObject var viewModel: WatchHomeViewModel
    let onBack: () -> Void

    private var folder: MagicItem? {
        viewModel.watchConfig.items.first(where: { $0.type == .folder && $0.id == folderId })
    }

    var body: some View {
        List {
            header
            ForEach(folder?.items ?? [], id: \.viewIdentity) { item in
                WatchMagicViewRow(
                    item: item,
                    itemInfo: viewModel.info(for: item)
                )
            }
        }
        .ignoresSafeArea([.all], edges: .top)
    }

    private var header: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemSymbol: .chevronLeft)
            }
            .buttonStyle(.plain)
            .circularGlassOrLegacyBackground()
            Text(folder?.displayText ?? L10n.Watch.Configuration.Folder.defaultName)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }
}
