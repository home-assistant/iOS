import SFSafeSymbols
import Shared
import SwiftUI

struct WatchFolderContentView: View {
    let folderId: String
    @ObservedObject var viewModel: WatchHomeViewModel
    let onBack: () -> Void

    @State private var isEditing = false
    @State private var activeSheet: WatchHomeView.HomeSheet?

    private var folder: MagicItem? {
        viewModel.watchConfig.items.first(where: { $0.type == .folder && $0.id == folderId })
    }

    var body: some View {
        List {
            header
            itemsContent
            if !isEditing {
                addRow
            }
        }
        .id(viewModel.configVersion)
        .ignoresSafeArea([.all], edges: .top)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.hidden, for: .navigationBar)
            } else {
                view.toolbar(.hidden, for: .navigationBar)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                WatchConfigAddView(viewModel: viewModel, folderId: folderId)
            case let .edit(editable):
                NavigationView {
                    WatchConfigItemEditView(
                        mode: .edit,
                        placeholderName: viewModel.info(for: editable.item).name,
                        item: editable.item,
                        info: viewModel.info(for: editable.item)
                    ) { item in
                        viewModel.updateItem(item, info: viewModel.info(for: editable.item))
                        activeSheet = nil
                    } onDelete: {
                        viewModel.removeItem(editable.item)
                        viewModel.saveConfig()
                        activeSheet = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var itemsContent: some View {
        if !isEditing, viewModel.watchConfig.resolvedLayout == .grid {
            gridContent
        } else {
            listItems
        }
    }

    private var listItems: some View {
        ForEach(Array((folder?.items ?? []).enumerated()), id: \.offset) { index, item in
            rowContent(for: item, at: index)
                .modify { view in
                    if isEditing {
                        view
                    } else {
                        view.onLongPressGesture { enterEditMode() }
                    }
                }
        }
        .onMove(perform: isEditing ? moveItems : nil)
        .onDelete(perform: isEditing ? deleteItems : nil)
    }

    private var gridContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60), spacing: DesignSystem.Spaces.one)],
            spacing: DesignSystem.Spaces.one
        ) {
            ForEach(Array((folder?.items ?? []).enumerated()), id: \.offset) { _, item in
                WatchMagicViewRow(item: item, itemInfo: viewModel.info(for: item), layout: .grid)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    @ViewBuilder
    private func rowContent(for item: MagicItem, at index: Int) -> some View {
        if isEditing {
            VStack(spacing: DesignSystem.Spaces.half) {
                Button {
                    activeSheet = .edit(.init(id: item.serverUniqueId, item: item))
                } label: {
                    WatchConfigItemRow(item: item, itemInfo: viewModel.info(for: item))
                }
                .buttonStyle(.plain)
                WatchReorderControls(
                    upDisabled: index == 0,
                    downDisabled: index == (folder?.items?.count ?? 0) - 1,
                    onUp: { viewModel.moveItemUpInFolder(folderId: folderId, at: index) },
                    onDown: { viewModel.moveItemDownInFolder(folderId: folderId, at: index) }
                )
            }
            .watchConfigRowBackground()
        } else {
            WatchMagicViewRow(
                item: item,
                itemInfo: viewModel.info(for: item),
                subtitle: viewModel.serverName(for: item)
            )
        }
    }

    private var header: some View {
        HStack {
            Button {
                if isEditing {
                    withAnimation { isEditing = false }
                    viewModel.saveConfig()
                }
                onBack()
            } label: {
                Image(systemSymbol: .chevronLeft)
            }
            .buttonStyle(.plain)
            .circularGlassOrLegacyBackground()
            Text(folder?.displayText ?? L10n.Watch.Configuration.Folder.defaultName)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isEditing {
                doneButton
            } else if !(folder?.items?.isEmpty ?? true) {
                editButton
            }
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }

    private var editButton: some View {
        Button {
            enterEditMode()
        } label: {
            Image(systemSymbol: .pencil)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground()
    }

    private var addRow: some View {
        Button {
            activeSheet = .add
        } label: {
            Label(L10n.Watch.Config.Add.title, systemSymbol: .plus)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .watchItemRowStyle()
    }

    private var doneButton: some View {
        Button {
            withAnimation { isEditing = false }
            viewModel.saveConfig()
        } label: {
            Image(systemSymbol: .checkmark)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground(tint: .haPrimary)
    }

    private func enterEditMode() {
        withAnimation { isEditing = true }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        viewModel.moveItemWithinFolder(folderId: folderId, from: source, to: destination)
    }

    private func deleteItems(at offsets: IndexSet) {
        viewModel.deleteItemInFolder(folderId: folderId, at: offsets)
    }
}
