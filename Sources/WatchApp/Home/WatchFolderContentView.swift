import SFSafeSymbols
import Shared
import SwiftUI

/// A folder's contents, pushed by `WatchFolderRow` through the home screen's `NavigationStack`.
/// The navigation bar stays hidden — the custom header provides the back button (via `dismiss`),
/// keeping the same look it had before folders were real pushes.
struct WatchFolderContentView: View {
    let folderId: String
    @ObservedObject var viewModel: WatchHomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var activeSheet: WatchHomeView.HomeSheet?

    private var folder: MagicItem? {
        viewModel.watchConfig.items.first(where: { $0.type == .folder && $0.id == folderId })
    }

    var body: some View {
        List {
            header
            itemsContent
            if isEditing {
                // The header's Done scrolls off once the list is long enough to reorder in, so
                // finishing is reachable from the bottom too — matching the home screen's footer.
                doneFooterRow
            } else {
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
        // No long-press-to-edit here: a gesture on the row swallows the tap of the `Button` it is built
        // from on watchOS before 26, which left every item unresponsive. Edit mode is entered from the
        // header's pencil button instead.
        ForEach(Array((folder?.items ?? []).enumerated()), id: \.element.serverUniqueId) { index, item in
            rowContent(for: item, at: index)
        }
        .onMove(perform: isEditing ? moveItems : nil)
        .onDelete(perform: isEditing ? deleteItems : nil)
    }

    // Complications follow the grid as full-width rows: a rectangular layout has nothing to show
    // inside a 60-point square tile.
    @ViewBuilder
    private var gridContent: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60), spacing: DesignSystem.Spaces.one)],
            spacing: DesignSystem.Spaces.one
        ) {
            ForEach((folder?.items ?? []).filter { $0.type != .complication }, id: \.serverUniqueId) { item in
                if item.type == .area {
                    WatchAreaItemRow(item: item, itemInfo: viewModel.info(for: item), layout: .grid)
                } else {
                    WatchMagicViewRow(item: item, itemInfo: viewModel.info(for: item), layout: .grid)
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        ForEach((folder?.items ?? []).filter { $0.type == .complication }, id: \.serverUniqueId) { item in
            WatchComplicationRow(item: item, itemInfo: viewModel.info(for: item))
        }
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
        } else if item.type == .area {
            WatchAreaItemRow(
                item: item,
                itemInfo: viewModel.info(for: item),
                subtitle: viewModel.serverName(for: item)
            )
        } else if item.type == .complication {
            WatchComplicationRow(item: item, itemInfo: viewModel.info(for: item))
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
                dismiss()
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

    private var doneFooterRow: some View {
        HStack {
            Spacer()
            doneButton
            Spacer()
        }
        .padding(DesignSystem.Spaces.one)
        .listRowBackground(Color.clear)
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
