import SwiftUI

@available(iOS 26.0, *)
struct DomainSummaryCard: View {
    let summary: HomeViewModel.DomainSummary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: summary.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(summary.isActive ? .orange : .secondary)
                    .frame(width: 44, height: 44)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text(summary.summaryText)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 26.0, *)
struct DomainSummariesSection: View {
    let summaries: [HomeViewModel.DomainSummary]
    let onTapSummary: (HomeViewModel.DomainSummary) -> Void
    
    var body: some View {
        if !summaries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                Text("Summaries")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                
                // Grid of summary cards
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(summaries) { summary in
                        DomainSummaryCard(summary: summary) {
                            onTapSummary(summary)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
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
        )
    ]
    
    return DomainSummariesSection(summaries: summaries) { summary in
        print("Tapped: \(summary.displayName)")
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
