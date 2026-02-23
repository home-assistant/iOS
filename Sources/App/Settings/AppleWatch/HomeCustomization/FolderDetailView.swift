import SFSafeSymbols
import Shared
import SwiftUI

struct FolderDetailView: View {
    let folderId: String
    @ObservedObject var viewModel: WatchConfigurationViewModel

    @State private var showAddItem = false
    @State private var showEditFolder = false

    private var folder: MagicItem? {
        viewModel.watchConfig.items.first(where: { $0.type == .folder && $0.id == folderId })
    }

    var body: some View {
        List {
            Section {
                ForEach(folderItems, id: \.serverUniqueId) { item in
                    row(for: item)
                }
                .onMove { indices, newOffset in
                    viewModel.moveItemWithinFolder(folderId: folderId, from: indices, to: newOffset)
                }
                .onDelete { indexSet in
                    viewModel.deleteItemInFolder(folderId: folderId, at: indexSet)
                }
                Button {
                    showAddItem = true
                } label: {
                    Label(L10n.Watch.Configuration.AddItem.title, systemSymbol: .plus)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(folder?.displayText ?? L10n.Watch.Configuration.Folder.defaultName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditFolder = true
                } label: {
                    Image(systemSymbol: .gearshape)
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            MagicItemAddView(context: .watch) { itemToAdd in
                guard let itemToAdd else { return }
                viewModel.addItemToFolder(folderId: folderId, item: itemToAdd)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showEditFolder) {
            if let folder {
                NavigationView {
                    FolderEditView(folder: folder) { updatedFolder in
                        viewModel.updateFolder(updatedFolder)
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    private var folderItems: [MagicItem] {
        if let folder = viewModel.watchConfig.items.first(where: { $0.type == .folder && $0.id == folderId }) {
            return folder.items ?? []
        }
        return []
    }

    @ViewBuilder
    private func row(for item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item) ?? .init(
            id: item.id,
            name: item.id,
            iconName: "",
            customization: nil
        )

        if item.type == .action {
            HStack {
                Image(uiImage: image(for: item, itemInfo: itemInfo))
                    .renderingMode(.original)
                Text(item.name(info: itemInfo))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemSymbol: .line3Horizontal)
                    .foregroundStyle(.gray)
            }
        } else {
            NavigationLink {
                MagicItemCustomizationView(mode: .edit, context: .watch, item: item) { updatedMagicItem in
                    viewModel.updateItem(updatedMagicItem)
                }
            } label: {
                HStack {
                    Image(uiImage: image(for: item, itemInfo: itemInfo))
                        .renderingMode(.original)
                    Text(item.name(info: itemInfo))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemSymbol: .line3Horizontal)
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    private func image(for item: MagicItem, itemInfo: MagicItem.Info) -> UIImage {
        let icon: MaterialDesignIcons = item.icon(info: itemInfo)
        let color: UIColor = if let iconColor = item.customization?.iconColor ?? itemInfo.customization?.iconColor {
            .init(hex: iconColor)
        } else {
            .haPrimary
        }
        return icon.image(ofSize: .init(width: 18, height: 18), color: color)
    }
}

#Preview {
    let vm = WatchConfigurationViewModel()
    vm.watchConfig.items = [
        MagicItem(
            id: "folder1",
            serverId: "",
            type: .folder,
            customization: .init(),
            action: .default,
            displayText: "My Folder",
            items: [
                MagicItem(id: "script.turn_on", serverId: "s1", type: .script),
                MagicItem(id: "scene.night", serverId: "s1", type: .scene),
            ]
        ),
    ]
    return NavigationView { FolderDetailView(folderId: "folder1", viewModel: vm) }
}
