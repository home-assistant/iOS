import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Shared UI components for entity display views
@available(iOS 26.0, *)
enum EntityDisplayComponents {
    // MARK: - Constants

    /// Standard grid column configuration used across entity views
    static let standardGridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 150, maximum: 250), spacing: DesignSystem.Spaces.oneAndHalf),
    ]

    // MARK: - Loading View

    static var loadingView: some View {
        ProgressView()
            .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Error View

    static func errorView(_ errorMessage: String) -> some View {
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

    // MARK: - Empty State View

    static func emptyStateView(message: String) -> some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .house)
                .font(.system(size: DesignSystem.Spaces.six))
                .foregroundColor(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Entity Tiles Grid

    static func entityTilesGrid(
        entities: [HAEntity],
        server: Server,
        isHidden: Bool = false,
        contextMenuContent: @escaping (HAEntity) -> some View
    ) -> some View {
        LazyVGrid(columns: standardGridColumns, spacing: DesignSystem.Spaces.oneAndHalf) {
            ForEach(entities, id: \.entityId) { entity in
                HomeEntityTileView(
                    server: server,
                    haEntity: entity
                )
                .contentShape(Rectangle())
                .opacity(isHidden ? 0.6 : 1.0)
                .contextMenu {
                    contextMenuContent(entity)
                }
            }
        }
    }

    // MARK: - Reorderable Entity Grid

    /// Reorderable entity grid with drag and drop support
    static func reorderableEntityTilesGrid(
        entities: [HAEntity],
        server: Server,
        draggedEntity: Binding<String?>,
        roomId: String,
        viewModel: HomeViewModel
    ) -> some View {
        LazyVGrid(columns: standardGridColumns, spacing: DesignSystem.Spaces.oneAndHalf) {
            ForEach(entities, id: \.entityId) { entity in
                HomeEntityTileView(
                    server: server,
                    haEntity: entity
                )
                .contentShape(Rectangle())
                .modifier(EditModeIndicatorModifier(
                    isEditing: true,
                    isDragging: draggedEntity.wrappedValue == entity.entityId
                ))
                .onDrag {
                    draggedEntity.wrappedValue = entity.entityId
                    return NSItemProvider(object: entity.entityId as NSString)
                }
                .onDrop(of: [.text], delegate: EntityDropDelegate(
                    entity: entity,
                    entities: entities,
                    draggedEntity: draggedEntity,
                    roomId: roomId,
                    viewModel: viewModel
                ))
            }
        }
    }

    // MARK: - Section Header

    /// Standard section header with title and optional chevron for navigation
    static func sectionHeader(
        _ title: String,
        showChevron: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    sectionHeaderContent(title: title, showChevron: showChevron)
                }
                .buttonStyle(.plain)
            } else {
                sectionHeaderContent(title: title, showChevron: showChevron)
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.one)
    }

    private static func sectionHeaderContent(title: String, showChevron: Bool) -> some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .lineLimit(1)
                .truncationMode(.middle)
            if showChevron {
                Image(systemSymbol: .chevronRight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignSystem.Spaces.one)
    }

    // MARK: - Reorder Mode Toolbar

    /// Standard "Done" button for reorder mode toolbar
    static func reorderModeDoneButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Done")
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Context Menu Items

    /// Standard "Enter edit mode" button for entity context menus
    static func enterEditModeButton(isReorderMode: Binding<Bool>) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isReorderMode.wrappedValue = true
            }
        } label: {
            Label("Enter edit mode", systemSymbol: .arrowUpArrowDownCircle)
        }
    }

    // MARK: - Conditional Entity Grid

    /// Shows either reorderable or normal entity grid based on mode
    static func conditionalEntityGrid(
        entities: [HAEntity],
        server: Server,
        isReorderMode: Bool,
        isHidden: Bool = false,
        draggedEntity: Binding<String?>,
        roomId: String,
        viewModel: HomeViewModel,
        contextMenuContent: @escaping (HAEntity) -> some View
    ) -> some View {
        Group {
            if isReorderMode, !isHidden {
                reorderableEntityTilesGrid(
                    entities: entities,
                    server: server,
                    draggedEntity: draggedEntity,
                    roomId: roomId,
                    viewModel: viewModel
                )
            } else {
                entityTilesGrid(
                    entities: entities,
                    server: server,
                    isHidden: isHidden,
                    contextMenuContent: contextMenuContent
                )
            }
        }
    }
}
