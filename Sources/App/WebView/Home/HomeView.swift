import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var showSettings = false
    @State private var selectedSectionIds: Set<String> = []
    @State private var allowMultipleSelection = false
    @State private var showReorder = false
    @Environment(\.dismiss) private var dismiss

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(server: server))
    }

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle(viewModel.server.info.name)
                .navigationSubtitle("Connected")
                .navigationBarTitleDisplayMode(.large)
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
                .task {
                    await viewModel.loadEntities()
                    viewModel.loadSectionOrderIfNeeded()
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
                selectedSectionIds: selectedSectionIds
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
                .filteredSections(sectionOrder: viewModel.sectionOrder, selectedSectionIds: selectedSectionIds).isEmpty
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
            Text("No entities found")
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
                    selectedSectionIds: selectedSectionIds
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
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if viewModel.groupedEntities.isEmpty {
                    Text("No sections available")
                        .foregroundColor(.secondary)
                } else {
                    Toggle(isOn: Binding(
                        get: { selectedSectionIds.isEmpty },
                        set: { isOn in
                            if isOn {
                                // Turning 'Show All' on clears filters
                                selectedSectionIds.removeAll()
                            } else {
                                // Optionally do nothing when turning off
                            }
                        }
                    )) {
                        Text("Show All")
                    }

                    Toggle(isOn: $allowMultipleSelection) {
                        Text("Allow multiple selection")
                    }

                    Divider()

                    ForEach(viewModel.groupedEntities) { section in
                        Toggle(isOn: Binding(
                            get: { selectedSectionIds.contains(section.id) },
                            set: { _ in
                                selectedSectionIds = viewModel.toggledSelection(
                                    for: section.id,
                                    current: selectedSectionIds,
                                    allowMultipleSelection: allowMultipleSelection
                                )
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
                    Label("Reorder", systemSymbol: .listDash)
                }

                Button {
                    dismiss()
                } label: {
                    Label("Open web UI", systemSymbol: .safari)
                }

                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemSymbol: .gearshape)
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
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    HomeView(server: ServerFixture.standard)
}
