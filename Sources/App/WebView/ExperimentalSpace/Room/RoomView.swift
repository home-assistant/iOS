import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct RoomView: View {
    @StateObject private var viewModel: RoomViewModel
    @Environment(\.dismiss) private var dismiss

    init(server: Server, roomId: String, roomName: String) {
        _viewModel = StateObject(wrappedValue: RoomViewModel(
            server: server,
            roomId: roomId,
            roomName: roomName
        ))
    }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(viewModel.roomName)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemSymbol: .xmark)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(ModernAssistBackgroundView(theme: .homeAssistant))
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
            } else if viewModel.allEntities.isEmpty {
                EntityDisplayComponents.emptyStateView(message: L10n.RoomView.EmptyState.noEntities)
            } else {
                entitiesListView
            }
        }
        .animation(DesignSystem.Animation.default, value: viewModel.isLoading)
        .animation(DesignSystem.Animation.default, value: viewModel.errorMessage)
        .animation(DesignSystem.Animation.default, value: viewModel.allEntities.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entitiesListView: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: DesignSystem.Spaces.three
            ) {
                // Group entities by visibility status (checking against user's hidden entities)
                let hiddenEntities = viewModel.allEntities.filter { viewModel.hiddenEntityIds.contains($0.entityId) }
                let visibleEntities = viewModel.allEntities.filter { !viewModel.hiddenEntityIds.contains($0.entityId) }

                if !visibleEntities.isEmpty {
                    Section {
                        entityTilesGrid(for: visibleEntities)
                    }
                }

                if !hiddenEntities.isEmpty {
                    Section {
                        entityTilesGrid(for: hiddenEntities, isHidden: true)
                    } header: {
                        sectionHeader(L10n.RoomView.Section.hidden)
                    }
                }
            }
            .padding()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Component Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSystem.Spaces.one)
    }

    private func entityTilesGrid(for entities: [HAAppEntity], isHidden: Bool = false) -> some View {
        EntityDisplayComponents.entityTilesGrid(
            entities: entities,
            server: viewModel.server,
            entityStates: viewModel.entityStates,
            isHidden: isHidden
        ) { entity in
            Group {
                if isHidden {
                    Button {
                        viewModel.unhideEntity(entity.entityId)
                    } label: {
                        Label(L10n.RoomView.ContextMenu.unhide, systemSymbol: .eye)
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    RoomView(server: ServerFixture.standard, roomId: "living_room", roomName: "Living Room")
}
