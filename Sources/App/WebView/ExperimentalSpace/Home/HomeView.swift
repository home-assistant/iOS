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
    @State private var showCustomize = false
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
                .background(Color.secondaryBackground)
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
        .sheet(isPresented: $showCustomize) {
            HomeViewCustomizationView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showAssist, content: {
            AssistView.build(server: viewModel.server)
                .navigationTransition(.zoom(sourceID: assistAnimationSourceID, in: assist))
        })
        .fullScreenCover(item: Binding(
            get: { selectedRoom.map { RoomIdentifier(id: $0.id, name: $0.name) } },
            set: { selectedRoom = $0.map { ($0.id, $0.name) } }
        )) { room in
            if let section = viewModel.groupedEntities.first(where: { $0.id == room.id }), let selectedRoom {
                RoomView(section: section, viewModel: viewModel)
                    .navigationTransition(.zoom(sourceID: selectedRoom.id, in: roomNameSpace))
            }
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
        let layout = viewModel.configuration.areasLayout ?? .list

        return ScrollView {
            switch layout {
            case .grid:
                areasGridView(sections: filteredSections)
            case .list:
                areasListView(sections: filteredSections)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func areasListView(sections: [HomeViewModel.RoomSection]) -> some View {
        LazyVStack(
            alignment: .leading,
            spacing: DesignSystem.Spaces.three
        ) {
            predictionSection

            // Display regular sections
            ForEach(sections) { section in
                let visibleEntities = visibleEntitiesForSection(section)
                if !visibleEntities.isEmpty || viewModel.configuration.visibleSectionIds.contains(section.id) {
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
        }
        .padding()
    }

    private func areasGridView(sections: [HomeViewModel.RoomSection]) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            predictionSection
                .padding([.top, .horizontal])

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                EntityDisplayComponents.sectionHeader(
                    L10n.HomeView.Areas.title,
                    showChevron: false
                )
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: DesignSystem.Spaces.one)
                    ],
                    spacing: DesignSystem.Spaces.one
                ) {
                    ForEach(sections) { section in
                        if !isReorderMode {
                            AreaGridButton(
                                section: section,
                                action: {
                                    selectedRoom = (id: section.id, name: section.name)
                                }
                            )
                            .matchedTransitionSource(id: section.id, in: roomNameSpace)
                        }
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var predictionSection: some View {
        if viewModel.configuration.showUsagePredictionSection {
            // Display usage prediction common control section at the top
            if let usagePredictionSection = viewModel.usagePredictionSection {
                let visibleEntities = visibleEntitiesForSection(usagePredictionSection)
                if !visibleEntities.isEmpty {
                    Section {
                        entityTilesGrid(
                            for: visibleEntities,
                            section: usagePredictionSection
                        )
                    } header: {
                        sectionHeader(usagePredictionSection.name, section: usagePredictionSection)
                    }
                }
            }
        }
    }

    private func visibleEntitiesForSection(_ section: HomeViewModel.RoomSection) -> [HAEntity] {
        // Create lookup dictionaries once to avoid O(n) searches for each entity
        let appEntitiesDict = Dictionary(
            uniqueKeysWithValues: (viewModel.appEntities ?? []).map { ($0.entityId, $0) }
        )
        let registryDict = Dictionary(
            uniqueKeysWithValues: (viewModel.registryEntities ?? []).map { ($0.entityId, $0) }
        )
        let hiddenEntityIdsSet = Set(viewModel.configuration.hiddenEntityIds)

        // Single pass filter with early returns
        let filteredEntityIds = section.entityIds.filter { entityId in
            // Check hidden first (fastest check)
            guard !hiddenEntityIdsSet.contains(entityId) else { return false }

            // Check app entity state
            guard let appEntity = appEntitiesDict[entityId] else { return false }
            guard !appEntity.isHidden, !appEntity.isDisabled else { return false }

            // Check registry category
            if let registry = registryDict[entityId] {
                guard registry.registry.entityCategory == nil else { return false }
            }

            return true
        }

        // Get entities from filtered IDs
        let entities = filteredEntityIds.compactMap { entityId in
            viewModel.entityStates[entityId]
        }

        // Sort using the configuration's entity order for this room
        let savedOrder = viewModel.configuration.entityOrderByRoom[section.id] ?? []

        if savedOrder.isEmpty {
            // No custom order, sort alphabetically by entity ID
            return entities.sorted { e1, e2 in
                e1.entityId < e2.entityId
            }
        } else {
            // Sort by saved order, with unordered items at the end (alphabetically)
            let orderIndex = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })
            return entities.sorted { e1, e2 in
                let i1 = orderIndex[e1.entityId] ?? Int.max
                let i2 = orderIndex[e2.entityId] ?? Int.max
                if i1 == i2 {
                    return e1.entityId < e2.entityId
                }
                return i1 < i2
            }
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
        reorderButton
        Divider()
        showAllButton
        allowMultipleSelectionButton
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
                if viewModel.configuration.allowMultipleSelection || viewModel.configuration.visibleSectionIds
                    .contains(section.id) {
                    Label(
                        section.name,
                        systemSymbol: viewModel.configuration.visibleSectionIds
                            .contains(section.id) ? .checkmark : .circle
                    )
                } else {
                    Text(section.name)
                }
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
                    showCustomize = true
                } label: {
                    Label(L10n.HomeView.Menu.customize, systemSymbol: .circleLefthalfFilledRighthalfStripedHorizontal)
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
            // Handle usage prediction section separately (not in groupedEntities)
            if section.id == HomeViewModel.usagePredictionSectionId {
                EntityDisplayComponents.sectionHeader(
                    title,
                    showChevron: false
                )
            } else if let section = viewModel.groupedEntities.first(where: { $0.name == title }) {
                EntityDisplayComponents.sectionHeader(
                    title,
                    showChevron: true,
                    action: {
                        selectedRoom = (id: section.id, name: section.name)
                    }
                )
                .disabled(isReorderMode)
                .matchedTransitionSource(id: section.id, in: roomNameSpace)
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
