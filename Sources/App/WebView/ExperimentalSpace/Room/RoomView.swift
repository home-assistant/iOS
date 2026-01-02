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

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(roomName)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
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
                .background(ModernAssistBackgroundView(theme: .homeAssistant))
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

    private var currentRoomSection: HomeViewModel.RoomSection? {
        viewModel.groupedEntities.first(where: { $0.id == roomId })
    }

    private var roomEntityIds: Set<String> {
        // Get area entity IDs directly from the database
        do {
            let areas = try AppArea.fetchAreas(for: viewModel.server.identifier.rawValue)
            if let area = areas.first(where: { $0.id == roomId }) {
                return area.entities
            }
        } catch {
            Current.Log.error("Failed to fetch area entities: \(error.localizedDescription)")
        }
        return []
    }

    private var allRoomEntities: [HAEntity] {
        // Get all entities from entity states that belong to this room
        viewModel.entityStates.values.filter { entity in
            roomEntityIds.contains(entity.entityId)
        }
    }

    private var visibleEntities: [HAEntity] {
        allRoomEntities.filter { entity in
            !viewModel.hiddenEntityIds.contains(entity.entityId)
        }
        .sorted { $0.entityId < $1.entityId }
    }

    private var hiddenEntities: [HAEntity] {
        allRoomEntities.filter { entity in
            viewModel.hiddenEntityIds.contains(entity.entityId)
        }
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
        EntityDisplayComponents.entityTilesGrid(
            entities: entities,
            server: server,
            isHidden: isHidden
        ) { entity in
            if isHidden {
                Button {
                    viewModel.unhideEntity(entity.entityId)
                } label: {
                    Label(L10n.RoomView.ContextMenu.unhide, systemSymbol: .eye)
                }
            } else {
                Button(role: .destructive) {
                    viewModel.hideEntity(entity.entityId)
                } label: {
                    Label("Hide", systemSymbol: .eyeSlash)
                }
            }
        }
    }

    // MARK: - Edit Sheet

    private var editEntitiesSheet: some View {
        NavigationStack {
            List {
                if !visibleEntities.isEmpty {
                    Section {
                        ForEach(visibleEntities, id: \.entityId) { entity in
                            entityRow(entity: entity, isHidden: false)
                        }
                    } header: {
                        Text("Visible Entities")
                    }
                }

                if !hiddenEntities.isEmpty {
                    Section {
                        ForEach(hiddenEntities, id: \.entityId) { entity in
                            entityRow(entity: entity, isHidden: true)
                        }
                    } header: {
                        Text("Hidden Entities")
                    }
                }
            }
            .navigationTitle("Edit Entities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showEditSheet = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func entityRow(entity: HAEntity, isHidden: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(entity.attributes.friendlyName ?? entity.entityId)
                    .font(.body)
                Text(entity.entityId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if isHidden {
                    viewModel.unhideEntity(entity.entityId)
                } else {
                    viewModel.hideEntity(entity.entityId)
                }
            } label: {
                Image(systemSymbol: isHidden ? .eye : .eyeSlash)
                    .foregroundStyle(isHidden ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .opacity(isHidden ? 0.6 : 1.0)
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
