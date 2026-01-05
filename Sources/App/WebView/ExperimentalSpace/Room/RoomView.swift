import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct RoomView: View {
    let server: Server
    let roomId: String
    let roomName: String

    @EnvironmentObject private var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showHidden = false
    @State private var showEditSheet = false
    @State private var isReorderMode = false
    @State private var draggedEntity: String?

    // Cache the computed entities to avoid recomputation
    @State private var cachedVisibleEntities: [HAEntity] = []
    @State private var cachedHiddenEntities: [HAEntity] = []
    @State private var lastUpdateHash: Int = 0

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(roomName)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if isReorderMode {
                        ToolbarItem(placement: .topBarTrailing) {
                            EntityDisplayComponents.reorderModeDoneButton {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isReorderMode = false
                                }
                                // Save when exiting reorder mode
                                let currentOrder = cachedVisibleEntities.map(\.entityId)
                                viewModel.saveEntityOrder(for: roomId, order: currentOrder)
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showEditSheet = true
                            } label: {
                                Text("Edit")
                            }
                            .buttonStyle(.plain)
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemSymbol: .xmark)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(ModernAssistBackgroundView(theme: .homeAssistant))
        }
        .animation(DesignSystem.Animation.default, value: showHidden)
        .sheet(isPresented: $showEditSheet) {
            editEntitiesSheet
        }
        .task(id: computeUpdateHash()) {
            // Update cached entities when data changes
            updateCachedEntities()
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: DesignSystem.Spaces.three
            ) {
                // Visible Entities Section
                if !cachedVisibleEntities.isEmpty {
                    entityTilesGrid(for: cachedVisibleEntities, isHidden: false)
                }

                // Show/Hide Hidden Entities Button
                if !cachedHiddenEntities.isEmpty {
                    Button {
                        withAnimation(DesignSystem.Animation.default) {
                            showHidden.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemSymbol: showHidden ? .eyeSlashFill : .eye)
                            Text(showHidden ? "Hide hidden entities" : "Show hidden entities")
                        }
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spaces.two)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Hidden Entities Section
                if showHidden, !cachedHiddenEntities.isEmpty {
                    Section {
                        entityTilesGrid(for: cachedHiddenEntities, isHidden: true)
                    } header: {
                        sectionHeader(L10n.RoomView.Section.hidden)
                    }
                }

                // Empty State
                if cachedVisibleEntities.isEmpty, cachedHiddenEntities.isEmpty {
                    EntityDisplayComponents.emptyStateView(message: L10n.RoomView.EmptyState.noEntities)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, DesignSystem.Spaces.six)
                }
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    private var currentRoomSection: HomeViewModel.RoomSection? {
        // Use the pre-computed room section from HomeViewModel
        viewModel.groupedEntities.first(where: { $0.id == roomId })
    }

    // MARK: - Helper Methods

    /// Compute a hash to detect when data needs updating
    private func computeUpdateHash() -> Int {
        var hasher = Hasher()
        hasher.combine(roomId)
        hasher.combine(viewModel.entityStates.count)
        hasher.combine(viewModel.hiddenEntityIds.count)
        hasher.combine(viewModel.getEntityOrder(for: roomId))
        return hasher.finalize()
    }

    /// Update cached entities - only called when data changes
    private func updateCachedEntities() {
        // Get entities directly from the pre-computed room section
        guard let roomSection = currentRoomSection else {
            cachedVisibleEntities = []
            cachedHiddenEntities = []
            return
        }

        // Visible entities are already filtered and sorted by HomeViewModel
        cachedVisibleEntities = roomSection.entities

        // Hidden entities: get all entity IDs from the room section's area
        // and filter for those that are hidden
        let allRoomEntityIds: Set<String>
        do {
            let areas = try AppArea.fetchAreas(for: viewModel.server.identifier.rawValue)
            if let area = areas.first(where: { $0.id == roomId }) {
                allRoomEntityIds = area.entities
            } else {
                allRoomEntityIds = []
            }
        } catch {
            Current.Log.error("Failed to fetch area entities: \(error.localizedDescription)")
            allRoomEntityIds = []
        }

        cachedHiddenEntities = allRoomEntityIds
            .compactMap { viewModel.entityStates[$0] }
            .filter { viewModel.hiddenEntityIds.contains($0.entityId) }
            .sorted { $0.entityId < $1.entityId }
    }

    // MARK: - Component Views

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        EntityDisplayComponents.sectionHeader(title, showChevron: false)
    }

    @ViewBuilder
    private func entityTilesGrid(for entities: [HAEntity], isHidden: Bool) -> some View {
        EntityDisplayComponents.conditionalEntityGrid(
            entities: entities,
            server: server,
            isReorderMode: isReorderMode,
            isHidden: isHidden,
            draggedEntity: $draggedEntity,
            roomId: roomId,
            viewModel: viewModel
        ) { entity in
            Group {
                if !isReorderMode {
                    if isHidden {
                        Button {
                            viewModel.unhideEntity(entity.entityId)
                        } label: {
                            Label(L10n.RoomView.ContextMenu.unhide, systemSymbol: .eye)
                        }
                    } else {
                        EntityDisplayComponents.enterEditModeButton(isReorderMode: $isReorderMode)

                        Button(role: .destructive) {
                            viewModel.hideEntity(entity.entityId)
                        } label: {
                            Label("Hide", systemSymbol: .eyeSlash)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Edit Sheet

    private var editEntitiesSheet: some View {
        EditRoomEntitiesView(
            visibleEntities: cachedVisibleEntities,
            hiddenEntities: cachedHiddenEntities,
            onHideEntity: { entityId in
                viewModel.hideEntity(entityId)
            },
            onUnhideEntity: { entityId in
                viewModel.unhideEntity(entityId)
            },
            onReorderEntities: { newOrder in
                viewModel.saveEntityOrder(for: roomId, order: newOrder)
            },
            onDismiss: {
                showEditSheet = false
            }
        )
    }
}

@available(iOS 26.0, *)
#Preview {
    RoomView(
        server: ServerFixture.standard,
        roomId: "room_1",
        roomName: "Living Room"
    )
    .environmentObject(HomeViewModel(server: ServerFixture.standard))
}
