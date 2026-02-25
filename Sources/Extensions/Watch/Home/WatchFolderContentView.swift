import SFSafeSymbols
import Shared
import SwiftUI

struct WatchFolderContentView: View {
    @Environment(\.dismiss) private var dismiss
    let folderId: String
    @ObservedObject var viewModel: WatchHomeViewModel

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
        ._statusBarHidden(true)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.hidden, for: .navigationBar)
            } else if #available(watchOS 9.0, *) {
                view.toolbar(.hidden, for: .navigationBar)
            } else {
                view.navigationBarHidden(true)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
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
