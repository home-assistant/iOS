import SFSafeSymbols
import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: WatchHomeViewModel
    /// When false, the view skips the network/database refresh on appear. Used by previews to render
    /// injected sample data.
    private let autoLoad: Bool
    @State private var showAssist = false
    @State private var showSettings = false
    @State private var openFolderId: String?
    @State private var isEditing = false
    @State private var activeSheet: HomeSheet?

    init(viewModel: WatchHomeViewModel = WatchHomeViewModel(), autoLoad: Bool = true) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.autoLoad = autoLoad
    }

    /// Identifiable wrapper so a `MagicItem` can drive a `.sheet(item:)`.
    struct EditableItem: Identifiable {
        let id: String
        let item: MagicItem
    }

    /// A single sheet enum avoids stacking multiple `.sheet` modifiers on one view, which is
    /// unreliable on older watchOS.
    enum HomeSheet: Identifiable {
        case add
        case edit(EditableItem)

        var id: String {
            switch self {
            case .add: return "__add__"
            case let .edit(editable): return editable.id
            }
        }
    }

    var body: some View {
        Group {
            if let folderId = openFolderId {
                WatchFolderContentView(folderId: folderId, viewModel: viewModel) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        openFolderId = nil
                    }
                }
                .transition(.move(edge: .trailing))
            } else {
                content
                    .transition(.move(edge: .leading))
            }
        }
        ._statusBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
            showAssist = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchConfigDidChange)) { _ in
            viewModel.loadCache()
        }
        .fullScreenCover(isPresented: $showAssist, content: {
            if let serverId = viewModel.watchConfig.assist.serverId,
               let pipelineId = viewModel.watchConfig.assist.pipelineId {
                WatchAssistView.build(
                    serverId: serverId,
                    pipelineId: pipelineId
                )
            } else {
                fatalError("Assist launched without serverId or pipelineId")
            }
        })
        .sheet(isPresented: $showSettings) {
            WatchSettingsView()
        }
        .onChange(of: showSettings) { isPresented in
            if !isPresented {
                viewModel.loadCache()
            }
        }
        .alert(
            Text(verbatim: L10n.Watch.Config.Conflict.title),
            isPresented: Binding(
                get: { viewModel.pendingConflict != nil },
                set: { if !$0 { viewModel.pendingConflict = nil } }
            )
        ) {
            Button(L10n.Watch.Config.Conflict.keepWatch) {
                viewModel.resolveConflictKeepingWatch()
            }
            Button(L10n.Watch.Config.Conflict.useIphone) {
                viewModel.resolveConflictUsingiPhone()
            }
        } message: {
            Text(verbatim: L10n.Watch.Config.Conflict.message)
        }
        .onAppear {
            guard autoLoad else { return }
            viewModel.startNetworkMonitoring()
            Task {
                await viewModel.fetchNetworkInfo()
                viewModel.initialRoutine()
            }
        }
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .active:
                Task {
                    await viewModel.fetchNetworkInfo()
                }
            case .background:
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            WatchHomeHeaderView(
                viewModel: viewModel,
                isEditing: $isEditing,
                onAssist: { showAssist = true },
                onAdd: { activeSheet = .add }
            )
            listContent
            if !isEditing, viewModel.showAssist {
                addRow
            }
            WatchHomeFooterView(
                viewModel: viewModel,
                isEditing: isEditing,
                onEdit: { enterEditMode() },
                onSettings: { showSettings = true }
            )
        }
        .id(viewModel.configVersion)
        // Removing the safe area so our fake navigation bar buttons (header) can be place correctly
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
                WatchConfigAddView(viewModel: viewModel, folderId: nil)
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
    private var listContent: some View {
        if viewModel.watchConfig.items.isEmpty {
            Text(verbatim: L10n.Watch.Labels.noConfigAdd)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        } else {
            mainContent
        }
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

    @ViewBuilder
    private var mainContent: some View {
        ForEach(Array(viewModel.watchConfig.items.enumerated()), id: \.offset) { index, item in
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
                    downDisabled: index == viewModel.watchConfig.items.count - 1,
                    onUp: { viewModel.moveItemUp(at: index) },
                    onDown: { viewModel.moveItemDown(at: index) }
                )
            }
            .watchConfigRowBackground()
        } else if item.type == .folder {
            WatchFolderRow(item: item, itemInfo: viewModel.info(for: item)) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    openFolderId = item.id
                }
            }
        } else {
            WatchMagicViewRow(
                item: item,
                itemInfo: viewModel.info(for: item),
                subtitle: viewModel.serverName(for: item)
            )
        }
    }

    private func enterEditMode() {
        withAnimation { isEditing = true }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        viewModel.moveItem(from: source, to: destination)
    }

    private func deleteItems(at offsets: IndexSet) {
        viewModel.deleteItem(at: offsets)
    }
}

#Preview("Populated") {
    MaterialDesignIcons.register()
    let viewModel = WatchHomeViewModel()
    viewModel.showAssist = true
    viewModel.watchConfig = WatchConfig(items: [
        MagicItem(
            id: "script.good_morning",
            serverId: "1",
            type: .script,
            customization: .init(iconColor: "#FFB300", icon: "weather_sunny"),
            displayText: "Good Morning"
        ),
        MagicItem(
            id: "scene.movie_time",
            serverId: "1",
            type: .scene,
            customization: .init(icon: "movie_open"),
            displayText: "Movie Time"
        ),
        MagicItem(
            id: "script.goodnight",
            serverId: "1",
            type: .script,
            customization: .init(backgroundColor: "#3F51B5", icon: "weather_night"),
            displayText: "Goodnight"
        ),
        MagicItem(
            id: "folder1",
            serverId: "",
            type: .folder,
            customization: .init(iconColor: "#4FC3F7"),
            displayText: "Lights",
            items: [
                MagicItem(
                    id: "light.kitchen",
                    serverId: "1",
                    type: .entity,
                    customization: .init(icon: "ceiling_light"),
                    displayText: "Kitchen"
                ),
            ]
        ),
    ])
    return WatchHomeView(viewModel: viewModel, autoLoad: false)
}

#Preview("Empty") {
    MaterialDesignIcons.register()
    let viewModel = WatchHomeViewModel()
    viewModel.watchConfig = WatchConfig(items: [])
    return WatchHomeView(viewModel: viewModel, autoLoad: false)
}
