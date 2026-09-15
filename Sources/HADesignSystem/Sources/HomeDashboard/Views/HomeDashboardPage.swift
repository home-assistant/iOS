#if !os(watchOS)
import SwiftUI

/// One screen of the generated dashboard — the overview or a room — with its greeting, its badges
/// and its sections.
///
/// Which sections are drawn depends on how wide the window is: the web dashboard puts its summaries
/// in a sidebar when there is room for one, and the strategy emits the same section twice so that
/// choice can be made here rather than regenerated.
public struct HomeDashboardPage: View {
    @Environment(\.homeDashboard) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var reorder: HomeAreaReorderCoordinator

    private let config: HomeDashboardViewConfig
    /// Every room on this screen in order, which a drag rewrites. Empty when nothing can be dragged.
    private let areaOrder: [String]

    public init(config: HomeDashboardViewConfig, areaOrder: [String] = []) {
        self.config = config
        self.areaOrder = areaOrder
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                if let header = config.header {
                    HomeWelcomeHeaderView(config: header)
                }
                if !config.badges.isEmpty {
                    badges
                }
                content
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.vertical, DesignSystem.Spaces.two)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.haSecondaryBackground)
        // A room dropped between the cards rather than onto one: nothing moved, but the drag has to
        // end somewhere or the grid would keep showing the order it was dragged into.
        .dropDestination(for: String.self) { _, _ in
            reorder.drop(original: areaOrder)
            return true
        }
    }

    private var badges: some View {
        FlowLayout(spacing: DesignSystem.Spaces.one) {
            ForEach(config.badges) { badge in
                HomeEntityBadgeView(config: badge)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch config.content {
        case let .sections(sections):
            if isCompact {
                flow(visibleSections(sections))
            } else {
                // Wide enough for the summaries to stand beside the rooms rather than above them,
                // which is where the web dashboard puts them and why the strategy emits them twice.
                HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                    flow(visibleSections(sections).filter { $0.visibility != .largeScreen })
                    let sidebar = visibleSections(sections).filter { $0.visibility == .largeScreen }
                    if !sidebar.isEmpty {
                        flow(sidebar)
                            .frame(width: Self.sidebarWidth)
                    }
                }
            }
        case let .panel(cards):
            VStack(spacing: DesignSystem.Spaces.two) {
                ForEach(cards) { card in
                    HomeDashboardCardView(config: card)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The frontend's sidebar column, which it caps so the rooms keep the room.
    private static let sidebarWidth: CGFloat = 340

    private func flow(_ sections: [HomeDashboardSectionConfig]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
            ForEach(sections) { section in
                HomeDashboardSectionView(config: section, areaOrder: areaOrder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isCompact: Bool {
        horizontalSizeClass != .regular
    }

    private func visibleSections(_ sections: [HomeDashboardSectionConfig]) -> [HomeDashboardSectionConfig] {
        sections.filter { $0.visibility.isVisible(isCompact: isCompact) }
    }
}

#Preview {
    let registry = HomeDashboardSampleHome.registry
    let dashboard = HomeDashboardStrategy.generate(
        config: HomeDashboardSampleHome.strategyConfig,
        registry: registry
    )
    return HomeDashboardPage(config: dashboard.overview!, areaOrder: registry.areas.map(\.id))
        .environment(\.homeDashboard, HomeDashboardContext(registry: registry))
        .environmentObject(HomeAreaReorderCoordinator { _ in })
}
#endif
