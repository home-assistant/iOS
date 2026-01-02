import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Shared UI components for entity display views
@available(iOS 26.0, *)
enum EntityDisplayComponents {
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
        let columns = [
            GridItem(.adaptive(minimum: 150, maximum: 250), spacing: DesignSystem.Spaces.oneAndHalf),
        ]

        return LazyVGrid(columns: columns, spacing: DesignSystem.Spaces.oneAndHalf) {
            ForEach(entities, id: \.entityId) { entity in
                EntityTileView(
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
}
