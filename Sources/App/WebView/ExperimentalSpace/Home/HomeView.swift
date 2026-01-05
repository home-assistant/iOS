import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeView: View {
    @Namespace private var assist
    @Namespace private var roomNameSpace
    private var assistAnimationSourceID = "assist"
    @StateObject private var viewModel: HomeViewModel
    @State private var showSettings = false
    @State private var showReorder = false
    @State private var showAssist = false
    @State private var selectedRoom: (id: String, name: String)?
    @State private var isReorderMode = false
    @State private var draggedEntity: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(server: server))
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(viewModel.server.info.name)
                .navigationSubtitle(L10n.HomeView.Navigation.Subtitle.experimental)
                .toolbar {
                    toolbarMenu
                }
                .background(ModernAssistBackgroundView(theme: .homeAssistant))
        }
        .onAppear {
            Task {
                await viewModel.loadEntities()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showReorder) {
            HomeSectionsReorderView(
                sections: viewModel.groupedEntities.map { ($0.id, $0.name) },
                sectionOrder: $viewModel.configuration.sectionOrder,
                onDone: {
                    /* no-op */
                }
            )
        }
        .fullScreenCover(isPresented: $showAssist, content: {
            AssistView.build(server: viewModel.server)
                .navigationTransition(.zoom(sourceID: assistAnimationSourceID, in: assist))
        })
        .fullScreenCover(item: Binding(
            get: { selectedRoom.map { RoomIdentifier(id: $0.id, name: $0.name) } },
            set: { selectedRoom = $0.map { ($0.id, $0.name) } }
        )) { room in
            RoomView(server: viewModel.server, roomId: room.id, roomName: room.name)
                .environmentObject(viewModel)
                .navigationTransition(.zoom(sourceID: selectedRoom?.id, in: roomNameSpace))
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }

    // MARK: - Lifecycle

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            viewModel.handleAppDidBecomeActive()
        case .background:
            viewModel.handleAppDidEnterBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Content Views

    private var contentView: some View {
        ZStack {
            if viewModel.isLoading {
                EntityDisplayComponents.loadingView
            } else if let errorMessage = viewModel.errorMessage {
                EntityDisplayComponents.errorView(errorMessage)
            } else if viewModel.filteredSections(
                sectionOrder: viewModel.configuration.sectionOrder,
                visibleSectionIds: viewModel.configuration.visibleSectionIds
            ).isEmpty {
                EntityDisplayComponents.emptyStateView(message: L10n.HomeView.EmptyState.noEntities)
            } else {
                entitiesListView
            }
        }
        .animation(DesignSystem.Animation.default, value: viewModel.isLoading)
        .animation(DesignSystem.Animation.default, value: viewModel.errorMessage)
        .animation(
            DesignSystem.Animation.default,
            value: viewModel
                .filteredSections(
                    sectionOrder: viewModel.configuration.sectionOrder,
                    visibleSectionIds: viewModel.configuration.visibleSectionIds
                ).isEmpty
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entitiesListView: some View {
        let filteredSections = viewModel.filteredSections(
            sectionOrder: viewModel.configuration.sectionOrder,
            visibleSectionIds: viewModel.configuration.visibleSectionIds
        )

        return ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: DesignSystem.Spaces.three
            ) {
                ForEach(filteredSections) { section in
                    let visibleEntities = visibleEntitiesForSection(section)

                    Section {
                        entityTilesGrid(
                            for: visibleEntities,
                            section: section
                        )
                    } header: {
                        sectionHeader(section.name, section: section)
                    }
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func visibleEntitiesForSection(_ section: HomeViewModel.RoomSection) -> [HAEntity] {
        let filteredEntityIds = section.entityIds.filter { entityId in
            guard let appEntity = viewModel.appEntities?.first(where: { $0.entityId == entityId }) else {
                return false
            }
            return !appEntity.isHidden && !appEntity.isDisabled
        }.filter { entityId in
            !viewModel.configuration.hiddenEntityIds.contains(entityId)
        }.filter { entityId in
            guard let registry = viewModel.registryEntities?.first(where: { registry in
                registry.entityId == entityId
            }) else {
                return true
            }
            return registry.registry.entityCategory == nil
        }

        return filteredEntityIds.compactMap { entityId in
            viewModel.entityStates[entityId]
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        if isReorderMode {
            reorderModeToolbar
        } else {
            normalModeToolbar
        }
    }

    private var reorderModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            EntityDisplayComponents.reorderModeDoneButton {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isReorderMode = false
                }
            }
        }
    }

    private var normalModeToolbar: some ToolbarContent {
        Group {
            assistButton
            filterMenu
            moreMenu
        }
    }

    private var assistButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showAssist = true
            } label: {
                Image(.messageProcessingOutline)
            }
            .buttonStyle(.glassProminent)
            .tint(.haPrimary)
            .matchedTransitionSource(id: assistAnimationSourceID, in: assist)
        }
    }

    private var filterMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if viewModel.groupedEntities.isEmpty {
                    Text(L10n.HomeView.Menu.noSectionsAvailable)
                        .foregroundColor(.secondary)
                } else {
                    filterMenuContent
                }
            } label: {
                Image(systemSymbol: .line3HorizontalDecrease)
            }
        }
    }

    @ViewBuilder
    private var filterMenuContent: some View {
        showAllButton
        allowMultipleSelectionButton
        reorderButton

        Divider()

        sectionFilterButtons
    }

    private var showAllButton: some View {
        Button {
            if !viewModel.configuration.visibleSectionIds.isEmpty {
                viewModel.configuration.visibleSectionIds.removeAll()
            }
        } label: {
            Label(
                L10n.HomeView.Menu.showAll,
                systemSymbol: viewModel.configuration.visibleSectionIds.isEmpty ? .checkmark : .circle
            )
        }
    }

    private var allowMultipleSelectionButton: some View {
        Button {
            viewModel.configuration.allowMultipleSelection.toggle()
        } label: {
            Label(
                L10n.HomeView.Menu.allowMultipleSelection,
                systemSymbol: viewModel.configuration.allowMultipleSelection ? .checkmark : .circle
            )
        }
    }

    private var reorderButton: some View {
        Button {
            showReorder = true
        } label: {
            Label(L10n.HomeView.Menu.reorder, systemSymbol: .listDash)
        }
    }

    private var sectionFilterButtons: some View {
        ForEach(viewModel.orderedSectionsForMenu) { section in
            Button {
                viewModel.configuration.visibleSectionIds = viewModel.toggledSelection(
                    for: section.id,
                    current: viewModel.configuration.visibleSectionIds,
                    allowMultipleSelection: viewModel.configuration.allowMultipleSelection
                )
            } label: {
                Label(
                    section.name,
                    systemSymbol: viewModel.configuration.visibleSectionIds.contains(section.id) ? .checkmark : .circle
                )
            }
        }
    }

    private var moreMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    dismiss()
                } label: {
                    Label(L10n.HomeView.Menu.openWebUi, systemSymbol: .safari)
                }

                Button {
                    showSettings = true
                } label: {
                    Label(L10n.HomeView.Menu.settings, systemSymbol: .gearshape)
                }
            } label: {
                Image(systemSymbol: .ellipsis)
            }
        }
    }

    // MARK: - Component Views

    @ViewBuilder
    private func sectionHeader(_ title: String, section: HomeViewModel.RoomSection) -> some View {
        Group {
            if let foundSection = viewModel.groupedEntities.first(where: { $0.name == title }) {
                EntityDisplayComponents.sectionHeader(
                    title,
                    showChevron: true,
                    action: {
                        selectedRoom = (id: foundSection.id, name: foundSection.name)
                    }
                )
                .disabled(isReorderMode)
                .matchedTransitionSource(id: foundSection.id, in: roomNameSpace)
            } else { EmptyView() }
        }
    }

    private func entityTilesGrid(for entities: [HAEntity], section: HomeViewModel.RoomSection) -> some View {
        EntityDisplayComponents.conditionalEntityGrid(
            entities: entities,
            server: viewModel.server,
            isReorderMode: isReorderMode,
            draggedEntity: $draggedEntity,
            roomId: section.id,
            viewModel: viewModel
        ) { entity in
            Group {
                EntityDisplayComponents.enterEditModeButton(isReorderMode: $isReorderMode)

                Button(role: .destructive) {
                    viewModel.hideEntity(entity.entityId)
                } label: {
                    Label(L10n.HomeView.ContextMenu.hide, systemSymbol: .eyeSlash)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    HomeView(server: ServerFixture.standard)
}
