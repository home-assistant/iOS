import Shared
import SwiftUI

@available(iOS 26.0, *)
struct DomainSummaryCard: View {
    let summary: HomeViewModel.DomainSummary
    let action: () -> Void

    var body: some View {
        EntityTileView(
            entityName: summary.displayName,
            entityState: summary.summaryText,
            icon: iconForDomain(summary.icon),
            iconColor: summary.isActive ? .orange : .gray,
            isUnavailable: false,
            onIconTap: action,
            onTileTap: action
        )
    }

    private func iconForDomain(_ systemName: String) -> MaterialDesignIcons {
        // Map system icon names to Material Design Icons
        // You can expand this mapping as needed
        switch systemName {
        case "lightbulb.fill":
            return .lightbulbIcon
        case "rectangle.on.rectangle.angled":
            return .curtainsIcon
        default:
            return .dotsHorizontalIcon
        }
    }
}

@available(iOS 26.0, *)
struct DomainSummariesSection: View {
    let summaries: [HomeViewModel.DomainSummary]
    let onTapSummary: (HomeViewModel.DomainSummary) -> Void

    var body: some View {
        if !summaries.isEmpty {
            Section {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DesignSystem.Spaces.one),
                        GridItem(.flexible(), spacing: DesignSystem.Spaces.one),
                    ],
                    spacing: DesignSystem.Spaces.one
                ) {
                    ForEach(summaries) { summary in
                        DomainSummaryCard(summary: summary) {
                            onTapSummary(summary)
                        }
                    }
                }
            } header: {
                EntityDisplayComponents.sectionHeader(
                    "Summaries", // TODO: Replace with L10n.HomeView.Summaries.title when available
                    showChevron: false
                )
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    let summaries = [
        HomeViewModel.DomainSummary(
            id: "light",
            domain: "light",
            displayName: "Lights",
            icon: "lightbulb.fill",
            count: 10,
            activeCount: 3,
            summaryText: "3 on"
        ),
        HomeViewModel.DomainSummary(
            id: "cover",
            domain: "cover",
            displayName: "Covers",
            icon: "rectangle.on.rectangle.angled",
            count: 5,
            activeCount: 0,
            summaryText: "All closed"
        ),
    ]

    return DomainSummariesSection(summaries: summaries) { summary in
        print("Tapped: \(summary.displayName)")
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
