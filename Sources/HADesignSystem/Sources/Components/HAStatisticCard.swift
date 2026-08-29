#if !os(watchOS)
import HAIconic
import SwiftUI

/// A statistic over a period — a month's energy, a day's mean temperature — rather than a reading
/// now. The SwiftUI counterpart of the frontend's `hui-statistic-card`.
///
/// The same shape as ``HAEntityCard``, with the period named where that one shows its footer: what
/// separates a statistic from a state is the window it was taken over, so the card always says.
public struct HAStatisticCard: View {
    private let name: String
    private let icon: MaterialDesignIcons?
    private let color: Color
    private let value: String
    private let unit: String?
    private let period: String
    private let onTap: (() -> Void)?

    /// - Parameter period: What the figure covers — "Today", "This month". The frontend derives it
    ///   from the card's period config; here it arrives already worded.
    public init(
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haDisabled,
        value: String,
        unit: String? = nil,
        period: String,
        onTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.value = value
        self.unit = unit
        self.period = period
        self.onTap = onTap
    }

    public var body: some View {
        HAEntityCard(
            name: name,
            icon: icon,
            color: color,
            value: value,
            unit: unit,
            footer: period,
            onTap: onTap
        )
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAStatisticCard(
            name: "Energy used",
            icon: .flashIcon,
            color: .haWarningColor,
            value: "412",
            unit: "kWh",
            period: "This month"
        )
        HAStatisticCard(name: "Mean temperature", value: "18.4", unit: "°C", period: "Last 7 days")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAStatisticCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-statistic-card" }
}

#endif
