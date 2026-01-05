import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct RoomView: View {
    let section: HomeViewModel.RoomSection
    @ObservedObject var viewModel: HomeViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showHidden = false
    @State private var showEditSheet = false
    @State private var isReorderMode = false
    @State private var draggedEntity: String?

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(section.name)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if isReorderMode {
                        ToolbarItem(placement: .topBarTrailing) {
                            EntityDisplayComponents.reorderModeDoneButton {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isReorderMode = false
                                }
                                // Save when exiting reorder mode
                                let currentOrder = visibleEntities.map(\.entityId)
                                viewModel.saveEntityOrder(for: section.id, order: currentOrder)
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
                .background(Color.secondaryBackground)
        }
        .animation(DesignSystem.Animation.default, value: showHidden)
        .sheet(isPresented: $showEditSheet) {
            editEntitiesSheet
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
                if !visibleEntities.isEmpty {
                    entityTilesGrid(for: visibleEntities, isHidden: false)
                }

                // Show/Hide Hidden Entities Button
                if !hiddenEntities.isEmpty {
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
                if showHidden, !hiddenEntities.isEmpty {
                    Section {
                        entityTilesGrid(for: hiddenEntities, isHidden: true)
                    } header: {
                        sectionHeader(L10n.RoomView.Section.hidden)
                    }
                }

                // Empty State
                if visibleEntities.isEmpty, hiddenEntities.isEmpty {
                    EntityDisplayComponents.emptyStateView(message: L10n.RoomView.EmptyState.noEntities)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, DesignSystem.Spaces.six)
                }
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    /// Get visible entities for this section using the same logic as HomeView
    private var visibleEntities: [HAEntity] {
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

    /// Get hidden entities for this section
    private var hiddenEntities: [HAEntity] {
        let hiddenEntityIdsSet = Set(viewModel.configuration.hiddenEntityIds)

        return section.entityIds
            .filter { hiddenEntityIdsSet.contains($0) }
            .compactMap { viewModel.entityStates[$0] }
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
            server: viewModel.server,
            isReorderMode: isReorderMode,
            isHidden: isHidden,
            draggedEntity: $draggedEntity,
            roomId: section.id,
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
            visibleEntities: visibleEntities,
            hiddenEntities: hiddenEntities,
            onHideEntity: { entityId in
                viewModel.hideEntity(entityId)
            },
            onUnhideEntity: { entityId in
                viewModel.unhideEntity(entityId)
            },
            onReorderEntities: { newOrder in
                viewModel.saveEntityOrder(for: section.id, order: newOrder)
            },
            onDismiss: {
                showEditSheet = false
            }
        )
    }
}

@available(iOS 26.0, *)
#Preview {
    if let section = HomeViewModel(server: ServerFixture.standard).groupedEntities.first {
        RoomView(
            section: section,
            viewModel: HomeViewModel(server: ServerFixture.standard)
        )
    }
}
