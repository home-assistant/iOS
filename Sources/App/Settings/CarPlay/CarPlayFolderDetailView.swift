import SFSafeSymbols
import Shared
import SwiftUI

/// Manages the items inside a CarPlay Quick Access folder. Folders can't contain other folders,
/// so the add menu only offers plain item types.
struct CarPlayFolderDetailView: View {
    let folderId: String
    @ObservedObject var viewModel: CarPlayConfigurationViewModel

    @State private var showEditFolder = false
    @State private var addItemDestination: CarPlayAddItemDestination?

    private var folder: MagicItem? {
        viewModel.config.folder(withId: folderId)
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
                CarPlayAddItemMenu(
                    showAddFolder: false,
                    onSelectDestination: { addItemDestination = $0 },
                    onAddFolder: {}
                )
            }
        }
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
        .sheet(item: $addItemDestination, content: { destination in
            switch destination {
            case .entity, .assist:
                if let magicItemType = destination.magicItemType, let pickerOption = destination.pickerOption {
                    MagicItemAddView(
                        context: .carPlay,
                        initialItemType: magicItemType,
                        visiblePickerOptions: [pickerOption]
                    ) { itemToAdd in
                        guard let itemToAdd else { return }
                        viewModel.addItemToFolder(folderId: folderId, item: itemToAdd)
                    }
                }
            case .assistPrompt:
                NavigationView {
                    AssistPromptMagicItemView(mode: .add) { itemToAdd in
                        viewModel.addItemToFolder(folderId: folderId, item: itemToAdd)
                    }
                }
                .navigationViewStyle(.stack)
            }
        })
        .sheet(isPresented: $showEditFolder) {
            if let folder {
                NavigationView {
                    FolderEditView(folder: folder, usesDarkColorScheme: false) { updatedFolder in
                        viewModel.updateFolder(updatedFolder)
                    }
                }
            }
        }
    }

    private var folderItems: [MagicItem] {
        // Folders can't nest in CarPlay. The view model already strips nested folders when the
        // configuration loads; filter here as well so this view never renders one.
        (folder?.items ?? []).filter { $0.type != .folder }
    }

    @ViewBuilder
    private func row(for item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item) ?? .init(
            id: item.id,
            name: item.id,
            iconName: "",
            customization: nil
        )

        if item.type == .assistPrompt {
            NavigationLink {
                AssistPromptMagicItemView(mode: .edit, item: item) { updatedMagicItem in
                    viewModel.updateItemInFolder(folderId: folderId, item: updatedMagicItem)
                }
            } label: {
                rowLabel(for: item, info: itemInfo)
            }
        } else {
            NavigationLink {
                MagicItemCustomizationView(mode: .edit, context: .carPlay, item: item) { updatedMagicItem in
                    viewModel.updateItemInFolder(folderId: folderId, item: updatedMagicItem)
                }
            } label: {
                rowLabel(for: item, info: itemInfo)
            }
        }
    }

    private func rowLabel(for item: MagicItem, info: MagicItem.Info) -> some View {
        HStack {
            Image(uiImage: item.icon(info: info).image(
                ofSize: .init(width: 18, height: 18),
                color: .accent
            ))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name(info: info))
                if let contextSubtitle = info.contextSubtitle {
                    Text(contextSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemSymbol: .line3Horizontal)
                .foregroundStyle(.gray)
        }
    }
}

#Preview {
    NavigationStack {
        CarPlayFolderDetailView(folderId: "folder1", viewModel: CarPlayConfigurationViewModel())
    }
}
