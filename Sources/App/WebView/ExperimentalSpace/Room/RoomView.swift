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
    @State private var entityOrder: [String] = []
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
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isReorderMode = false
                                }
                                saveEntityOrder()
                            } label: {
                                Text("Done")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
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
        .task {
            await loadEntityOrder()
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
        hasher.combine(entityOrder)
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

        // Visible entities are already filtered by HomeViewModel (non-hidden)
        let visible = roomSection.entities

        // Apply custom ordering if available
        if entityOrder.isEmpty {
            cachedVisibleEntities = visible
        } else {
            // Create order lookup once
            let orderIndex = Dictionary(uniqueKeysWithValues: entityOrder.enumerated().map { ($1, $0) })
            cachedVisibleEntities = visible.sorted { a, b in
                let ia = orderIndex[a.entityId] ?? Int.max
                let ib = orderIndex[b.entityId] ?? Int.max
                return ia == ib ? a.entityId < b.entityId : ia < ib
            }
        }

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
        HStack {
            Text(title)
                .font(.title2.bold())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignSystem.Spaces.one)
        .padding(.horizontal, DesignSystem.Spaces.one)
    }

    @ViewBuilder
    private func entityTilesGrid(for entities: [HAEntity], isHidden: Bool) -> some View {
        if isReorderMode, !isHidden {
            reorderableEntityTilesGrid(for: entities)
        } else {
            EntityDisplayComponents.entityTilesGrid(
                entities: entities,
                server: server,
                isHidden: isHidden
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
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isReorderMode = true
                                }
                            } label: {
                                Label("Enter edit mode", systemSymbol: .arrowUpArrowDownCircle)
                            }

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
    }

    // MARK: - Reorderable Grid

    @ViewBuilder
    private func reorderableEntityTilesGrid(for entities: [HAEntity]) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 150, maximum: 250), spacing: DesignSystem.Spaces.oneAndHalf),
        ]

        LazyVGrid(columns: columns, spacing: DesignSystem.Spaces.oneAndHalf) {
            ForEach(entities, id: \.entityId) { entity in
                EntityTileView(
                    server: server,
                    haEntity: entity
                )
                .contentShape(Rectangle())
                .modifier(EditModeIndicatorModifier(isEditing: true, isDragging: draggedEntity == entity.entityId))
                .onDrag {
                    draggedEntity = entity.entityId
                    return NSItemProvider(object: entity.entityId as NSString)
                }
                .onDrop(of: [.text], delegate: EntityDropDelegate(
                    entity: entity,
                    entities: entities,
                    draggedEntity: $draggedEntity,
                    entityOrder: $entityOrder
                ))
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
                entityOrder = newOrder
                saveEntityOrder()
            },
            onDismiss: {
                showEditSheet = false
            }
        )
    }

    // MARK: - Entity Order Persistence

    private var entityOrderCacheKey: String {
        "room.entityOrder.\(server.identifier.rawValue).\(roomId)"
    }

    private func loadEntityOrder() async {
        do {
            let order: [String] = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: entityOrderCacheKey)
                    .done { (order: [String]) in
                        continuation.resume(returning: order)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            entityOrder = order
        } catch {
            // If no cached order exists, use entity IDs from visible entities
            entityOrder = cachedVisibleEntities.map(\.entityId)
        }
    }

    private func saveEntityOrder() {
        Current.diskCache.set(entityOrder, for: entityOrderCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save entity order: \(error)")
            }
        }
    }
}

// MARK: - Drop Delegate

@available(iOS 26.0, *)
private struct EntityDropDelegate: DropDelegate {
    let entity: HAEntity
    let entities: [HAEntity]
    @Binding var draggedEntity: String?
    @Binding var entityOrder: [String]

    func performDrop(info: DropInfo) -> Bool {
        draggedEntity = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedEntity,
              draggedEntity != entity.entityId else { return }

        let from = entities.firstIndex { $0.entityId == draggedEntity }
        let to = entities.firstIndex { $0.entityId == entity.entityId }

        guard let from, let to else { return }

        if entityOrder.isEmpty {
            // Initialize order if empty
            entityOrder = entities.map(\.entityId)
        }

        // Find indices in the order array
        guard let fromIndex = entityOrder.firstIndex(of: draggedEntity),
              let toIndex = entityOrder.firstIndex(of: entity.entityId) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            entityOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }
}

// MARK: - Edit Mode Indicator Modifier

@available(iOS 26.0, *)
private struct EditModeIndicatorModifier: ViewModifier {
    let isEditing: Bool
    let isDragging: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 1.05 : scale)
            .opacity(isDragging ? 0.6 : 1.0)
            .shadow(
                color: isEditing ? .blue.opacity(0.3) : .clear,
                radius: isDragging ? 12 : 6,
                x: 0,
                y: isDragging ? 4 : 2
            )
            .overlay {
                if isEditing, !isDragging {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scale)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            .onAppear {
                if isEditing {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        scale = 1.02
                    }
                }
            }
            .onChange(of: isEditing) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        scale = 1.02
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
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
