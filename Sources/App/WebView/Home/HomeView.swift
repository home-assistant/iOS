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
                .task {
                    await viewModel.loadEntities()
                }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Content Views

    private var contentView: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.filteredSections(
                sectionOrder: viewModel.sectionOrder,
                selectedSectionIds: viewModel.selectedSectionIds
            ).isEmpty {
                emptyStateView
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

    private var loadingView: some View {
        ProgressView()
            .transition(.opacity.combined(with: .scale))
    }

    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .exclamationmarkTriangle)
                .font(.system(size: DesignSystem.Spaces.six))
                .foregroundColor(.secondary)
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .transition(.opacity.combined(with: .scale))
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .house)
                .font(.system(size: DesignSystem.Spaces.six))
                .foregroundColor(.secondary)
            Text(L10n.HomeView.EmptyState.noEntities)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .transition(.opacity.combined(with: .scale))
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
                    showReorder = true
                } label: {
                    Label(L10n.HomeView.Menu.reorder, systemSymbol: .listDash)
                }

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
        Text(title)
            .font(.title2.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSystem.Spaces.one)
    }

    private func entityTilesGrid(for entities: [HAAppEntity]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: DesignSystem.Spaces.oneAndHalf),
            GridItem(.flexible(), spacing: DesignSystem.Spaces.oneAndHalf),
        ]

        return LazyVGrid(columns: columns, spacing: DesignSystem.Spaces.oneAndHalf) {
            ForEach(entities) { entity in
                EntityTileView(
                    server: viewModel.server,
                    appEntity: entity,
                    haEntity: viewModel.entityStates[entity.entityId]
                )
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel.hideEntity(entity.entityId)
                    } label: {
                        Label(L10n.HomeView.ContextMenu.hide, systemSymbol: .eyeSlash)
                    }
                }
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    HomeView(server: ServerFixture.standard)
}
