import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var showSettings = false
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
            } else if viewModel.groupedEntities.isEmpty {
                emptyStateView
            } else {
                entitiesListView
            }
        }
        .animation(DesignSystem.Animation.default, value: viewModel.isLoading)
        .animation(DesignSystem.Animation.default, value: viewModel.errorMessage)
        .animation(DesignSystem.Animation.default, value: viewModel.groupedEntities.isEmpty)
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
                ForEach(viewModel.groupedEntities) { section in
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

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    /* no-op */
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
