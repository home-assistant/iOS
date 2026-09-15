#if !os(watchOS)
import SwiftUI

/// One section of a view: its cards in the twelve-column grid, with the rooms in it draggable when
/// the dashboard was given somewhere to send a new order.
public struct HomeDashboardSectionView: View {
    @EnvironmentObject private var reorder: HomeAreaReorderCoordinator

    private let config: HomeDashboardSectionConfig
    /// Every area on the screen, in order — a drag rewrites this whole list, not just this section's
    /// part of it, because that is what the server is given.
    private let areaOrder: [String]

    public init(config: HomeDashboardSectionConfig, areaOrder: [String] = []) {
        self.config = config
        self.areaOrder = areaOrder
    }

    public var body: some View {
        HomeDashboardGrid(spacing: DesignSystem.Spaces.one) {
            ForEach(cards) { card in
                HomeDashboardCardView(config: card)
                    .homeDashboardColumns(card.columns)
                    .modifier(HomeAreaDragModifier(areaId: areaId(of: card), areaOrder: areaOrder))
            }
        }
    }

    /// The section's cards with the rooms in the order being dragged into, when one is.
    private var cards: [HomeDashboardCardConfig] {
        guard reorder.liveOrder != nil else {
            return config.cards
        }
        let areaCards = config.cards.filter { areaId(of: $0) != nil }
        guard areaCards.count > 1 else {
            return config.cards
        }
        let order = reorder.order(from: areaOrder)
        let sorted = areaCards.sorted { first, second in
            let firstIndex = areaId(of: first).flatMap { order.firstIndex(of: $0) } ?? 0
            let secondIndex = areaId(of: second).flatMap { order.firstIndex(of: $0) } ?? 0
            return firstIndex < secondIndex
        }
        var remaining = sorted.makeIterator()
        return config.cards.map { card in
            areaId(of: card) == nil ? card : (remaining.next() ?? card)
        }
    }

    private func areaId(of card: HomeDashboardCardConfig) -> String? {
        if case let .area(area) = card {
            return area.areaId
        }
        return nil
    }
}

#Preview {
    let registry = HomeDashboardSampleHome.registry
    let dashboard = HomeDashboardStrategy.generate(config: HomeDashboardSampleHome.strategyConfig, registry: registry)
    return ScrollView {
        VStack(spacing: DesignSystem.Spaces.three) {
            ForEach(dashboard.overview?.content.sections ?? []) { section in
                HomeDashboardSectionView(config: section, areaOrder: registry.areas.map(\.id))
            }
        }
        .padding()
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: registry))
    .environmentObject(HomeAreaReorderCoordinator { _ in })
    .background(Color.haSecondaryBackground)
}

#endif
