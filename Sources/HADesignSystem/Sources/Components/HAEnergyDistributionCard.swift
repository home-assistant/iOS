#if !os(watchOS)
import HAIconic
import SwiftUI

/// Where the home's energy came from and where it went, as a set of labelled sources around a
/// consumption total. Covers the frontend's `hui-energy-distribution-card`.
///
/// The frontend draws this as a flow diagram with animated dots along its paths. Those dots are
/// continuous animation, which a snapshot cannot capture the same way twice, so this reads the same
/// figures as a summary instead — a decision, not an omission. See `ha-sankey-chart` in the parity
/// doc for the diagram proper.
public struct HAEnergyDistributionCard: View {
    /// One source or sink, with the figure already formatted.
    public struct Item: Identifiable, Sendable {
        public var id: String { name }
        public let name: String
        public let icon: MaterialDesignIcons
        public let value: String
        public let color: Color

        public init(name: String, icon: MaterialDesignIcons, value: String, color: Color) {
            self.name = name
            self.icon = icon
            self.value = value
            self.color = color
        }
    }

    private let title: String?
    private let sources: [Item]
    private let consumption: Item

    /// - Parameter consumption: The home's total, drawn apart from the sources because everything
    ///   else flows into it.
    public init(title: String? = nil, sources: [Item], consumption: Item) {
        self.title = title
        self.sources = sources
        self.consumption = consumption
    }

    public var body: some View {
        HACard(header: title) {
            VStack(spacing: DesignSystem.Spaces.two) {
                HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                    ForEach(sources) { source in
                        item(source)
                    }
                }
                Divider()
                item(consumption)
            }
            .padding(DesignSystem.Spaces.two)
        }
    }

    private func item(_ item: Item) -> some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            MaterialDesignIconsImage(icon: item.icon, size: 24)
                .foregroundStyle(item.color)
                .frame(width: 44, height: 44)
                .background(Circle().fill(item.color.opacity(0.2)))
            Text(item.value)
                .font(.system(size: 14, weight: .medium))
            Text(item.name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HAEnergyDistributionCard(
        title: "Energy distribution",
        sources: [
            .init(name: "Solar", icon: .solarPowerIcon, value: "12.4 kWh", color: .haWarningColor),
            .init(name: "Grid", icon: .transmissionTowerIcon, value: "6.1 kWh", color: .haPrimary),
            .init(name: "Battery", icon: .batteryIcon, value: "3.2 kWh", color: .haSuccessColor),
        ],
        consumption: .init(name: "Home", icon: .homeIcon, value: "21.7 kWh", color: .haPrimary)
    )
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAEnergyDistributionCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-energy-distribution-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
