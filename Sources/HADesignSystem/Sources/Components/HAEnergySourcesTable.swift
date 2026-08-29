#if !os(watchOS)
import SwiftUI

/// Every meter feeding the energy dashboard, grouped by kind, with a total per group and one for
/// the lot. The SwiftUI counterpart of the frontend's `hui-energy-sources-table-card`.
///
/// The cost column appears only when something has a cost: a table of blank cells says less than no
/// column at all, which is why the frontend decides the same way.
public struct HAEnergySourcesTable: View {
    private let title: String?
    private let groups: [HAEnergySourceGroup]
    private let totalEnergy: String
    private let totalCost: String?
    private let showsOnlyTotals: Bool

    /// - Parameter showsOnlyTotals: Collapses each group to its total, the frontend's
    ///   `show_only_totals` — for a dashboard that wants the shape of the month, not every meter.
    public init(
        title: String? = nil,
        groups: [HAEnergySourceGroup],
        totalEnergy: String,
        totalCost: String? = nil,
        showsOnlyTotals: Bool = false
    ) {
        self.title = title
        self.groups = groups
        self.totalEnergy = totalEnergy
        self.totalCost = totalCost
        self.showsOnlyTotals = showsOnlyTotals
    }

    /// Costs are shown only if there is a cost anywhere to show.
    private var showsCosts: Bool {
        totalCost != nil || groups.contains { $0.totalCost != nil || $0.rows.contains { $0.cost != nil } }
    }

    public var body: some View {
        HACard(header: title) {
            VStack(spacing: .zero) {
                ForEach(groups) { group in
                    if !showsOnlyTotals {
                        ForEach(group.rows) { row in
                            line(
                                name: row.name,
                                energy: row.energy,
                                cost: row.cost,
                                color: row.color,
                                isTotal: false
                            )
                        }
                    }
                    line(
                        name: group.title,
                        energy: group.totalEnergy,
                        cost: group.totalCost,
                        color: nil,
                        isTotal: true
                    )
                }
                Divider()
                line(name: "Total", energy: totalEnergy, cost: totalCost, color: nil, isTotal: true)
            }
            .padding(DesignSystem.Spaces.two)
        }
    }

    private func line(
        name: String,
        energy: String,
        cost: String?,
        color: Color?,
        isTotal: Bool
    ) -> some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            // The swatch marks a meter, so a group's own total line is indented to where the names
            // start rather than carrying one.
            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            } else {
                Color.clear.frame(width: 8, height: 8)
            }
            Text(name)
                .lineLimit(1)
            Spacer(minLength: DesignSystem.Spaces.one)
            Text(energy)
                .monospacedDigit()
            if showsCosts {
                Text(cost ?? "")
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .font(.system(size: 14, weight: isTotal ? .medium : .regular))
        .foregroundStyle(isTotal ? Color(uiColor: .label) : .secondary)
        .padding(.vertical, DesignSystem.Spaces.half)
        .accessibilityElement(children: .combine)
    }
}

private let sampleEnergyGroups = [
    HAEnergySourceGroup(
        id: "solar",
        title: "Solar total",
        rows: [
            .init(id: "roof", name: "Roof array", color: .haWarningColor, energy: "12.4 kWh"),
            .init(id: "shed", name: "Shed array", color: .haWarningColor.opacity(0.6), energy: "3.1 kWh"),
        ],
        totalEnergy: "15.5 kWh"
    ),
    HAEnergySourceGroup(
        id: "grid",
        title: "Grid total",
        rows: [
            .init(id: "import", name: "Grid import", color: .haPrimary, energy: "6.1 kWh", cost: "£1.83"),
            .init(id: "export", name: "Grid export", color: .haSuccessColor, energy: "-2.4 kWh", cost: "-£0.36"),
        ],
        totalEnergy: "3.7 kWh",
        totalCost: "£1.47"
    ),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAEnergySourcesTable(
            title: "Sources",
            groups: sampleEnergyGroups,
            totalEnergy: "19.2 kWh",
            totalCost: "£1.47"
        )
        HAEnergySourcesTable(
            groups: sampleEnergyGroups,
            totalEnergy: "19.2 kWh",
            totalCost: "£1.47",
            showsOnlyTotals: true
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAEnergySourcesTable: FrontendComponent {
    public static var frontendComponentName: String { "hui-energy-sources-table-card" }
}

#endif
