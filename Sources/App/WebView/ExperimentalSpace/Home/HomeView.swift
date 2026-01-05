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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showReorder) {
            HomeSectionsReorderView(
                sections: viewModel.groupedEntities.map { ($0.id, $0.name) },
                sectionOrder: $viewModel.configuration.sectionOrder,
                onDone: { viewModel.saveSectionOrder() }
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
        .task {
            await viewModel.loadEntities()
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
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: DesignSystem.Spaces.three
            ) {
                ForEach(viewModel.filteredSections(
                    sectionOrder: viewModel.configuration.sectionOrder,
                    visibleSectionIds: viewModel.configuration.visibleSectionIds
                )) { section in
                    Section {
                        entityTilesGrid(for: section.entities, section: section)
                    } header: {
                        sectionHeader(section.name, section: section)
                    }
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        // Done button when in reorder mode
        if isReorderMode {
            ToolbarItem(placement: .topBarTrailing) {
                EntityDisplayComponents.reorderModeDoneButton {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isReorderMode = false
                    }
                }
            }
        } else {
            // Normal toolbar items
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if viewModel.groupedEntities.isEmpty {
                        Text(L10n.HomeView.Menu.noSectionsAvailable)
                            .foregroundColor(.secondary)
                    } else {
                        Toggle(isOn: Binding(
                            get: { viewModel.configuration.visibleSectionIds.isEmpty },
                            set: { isOn in
                                if isOn {
                                    // Turning 'Show All' on clears filters
                                    viewModel.configuration.visibleSectionIds.removeAll()
                                    viewModel.saveFilterSettings()
                                }
                            }
                        )) {
                            Text(L10n.HomeView.Menu.showAll)
                        }

                        Toggle(isOn: Binding(
                            get: { viewModel.configuration.allowMultipleSelection },
                            set: { isOn in
                                viewModel.configuration.allowMultipleSelection = isOn
                                viewModel.saveFilterSettings()
                            }
                        )) {
                            Text(L10n.HomeView.Menu.allowMultipleSelection)
                        }

                        Button {
                            showReorder = true
                        } label: {
                            Label(L10n.HomeView.Menu.reorder, systemSymbol: .listDash)
                        }

                        Divider()

                        ForEach(viewModel.orderedSectionsForMenu) { section in
                            Toggle(isOn: Binding(
                                get: { viewModel.configuration.visibleSectionIds.contains(section.id) },
                                set: { _ in
                                    viewModel.configuration.visibleSectionIds = viewModel.toggledSelection(
                                        for: section.id,
                                        current: viewModel.configuration.visibleSectionIds,
                                        allowMultipleSelection: viewModel.configuration.allowMultipleSelection
                                    )
                                    viewModel.saveFilterSettings()
                                }
                            )) {
                                Text(section.name)
                            }
                        }
                    }
                } label: {
                    Image(systemSymbol: .line3HorizontalDecrease)
                }
            }
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
