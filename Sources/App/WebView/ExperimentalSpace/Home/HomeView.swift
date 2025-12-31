import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeView: View {
    @Namespace private var assist
    private var assistAnimationSourceID = "assist"
    @StateObject private var viewModel: HomeViewModel
    @State private var showSettings = false
    @State private var showReorder = false
    @State private var showAssist = false
    @State private var selectedRoom: (id: String, name: String)?
    @Environment(\.dismiss) private var dismiss

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
                sectionOrder: $viewModel.sectionOrder,
                onDone: { viewModel.saveSectionOrder() }
            )
        }
        .fullScreenCover(isPresented: $showAssist, content: {
            AssistView.build(server: viewModel.server)
                .navigationTransition(.zoom(sourceID: assistAnimationSourceID, in: assist))
        })
        .sheet(item: Binding(
            get: { selectedRoom.map { RoomIdentifier(id: $0.id, name: $0.name) } },
            set: { selectedRoom = $0.map { ($0.id, $0.name) } }
        )) { room in
            RoomView(server: viewModel.server, roomId: room.id, roomName: room.name)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onDisappear {
                    Task {
                        await viewModel.reloadAfterUnhide()
                    }
                }
        }
        .task {
            await viewModel.loadEntities()
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
                sectionOrder: viewModel.sectionOrder,
                selectedSectionIds: viewModel.selectedSectionIds
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
                    sectionOrder: viewModel.sectionOrder,
                    selectedSectionIds: viewModel.selectedSectionIds
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
                    sectionOrder: viewModel.sectionOrder,
                    selectedSectionIds: viewModel.selectedSectionIds
                )) { section in
                    Section {
                        entityTilesGrid(for: section.entities)
                    } header: {
                        sectionHeader(section.name)
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
                        get: { viewModel.selectedSectionIds.isEmpty },
                        set: { isOn in
                            if isOn {
                                // Turning 'Show All' on clears filters
                                viewModel.selectedSectionIds.removeAll()
                                viewModel.saveFilterSettings()
                            }
                        }
                    )) {
                        Text(L10n.HomeView.Menu.showAll)
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.allowMultipleSelection },
                        set: { isOn in
                            viewModel.allowMultipleSelection = isOn
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
                            get: { viewModel.selectedSectionIds.contains(section.id) },
                            set: { _ in
                                viewModel.selectedSectionIds = viewModel.toggledSelection(
                                    for: section.id,
                                    current: viewModel.selectedSectionIds,
                                    allowMultipleSelection: viewModel.allowMultipleSelection
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

    // MARK: - Component Views

    private func sectionHeader(_ title: String) -> some View {
        Button {
            // Find the section ID for this title
            if let section = viewModel.groupedEntities.first(where: { $0.name == title }) {
                selectedRoom = (id: section.id, name: section.name)
            }
        } label: {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemSymbol: .chevronRight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignSystem.Spaces.one)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignSystem.Spaces.one)
    }

    private func entityTilesGrid(for entities: [HAAppEntity]) -> some View {
        EntityDisplayComponents.entityTilesGrid(
            entities: entities,
            server: viewModel.server,
            entityStates: viewModel.entityStates
        ) { entity in
            Button(role: .destructive) {
                viewModel.hideEntity(entity.entityId)
            } label: {
                Label(L10n.HomeView.ContextMenu.hide, systemSymbol: .eyeSlash)
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    HomeView(server: ServerFixture.standard)
}

// MARK: - Supporting Types

@available(iOS 26.0, *)
private struct RoomIdentifier: Identifiable {
    let id: String
    let name: String
}
