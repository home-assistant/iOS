#if !os(watchOS)
import HAIconic
import SwiftUI

/// A sensor's current reading with its recent history sketched underneath. The SwiftUI counterpart
/// of the frontend's `hui-sensor-card`.
///
/// The frontend builds this as an `hui-entity-card` with a graph footer rather than as a card of its
/// own, and this keeps that shape: the head is ``HAEntityCard``'s and the footer is ``HASparkline``.
/// Passing no history draws the head alone, which is the frontend's `graph: none`.
public struct HASensorCard: View {
    private let name: String
    private let icon: MaterialDesignIcons?
    private let color: Color
    private let value: String
    private let unit: String?
    private let history: [Double]
    private let onTap: (() -> Void)?

    /// - Parameter history: Readings oldest first. The sparkline scales to whatever range they
    ///   cover, so the caller need not normalise them.
    public init(
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haPrimary,
        value: String,
        unit: String? = nil,
        history: [Double] = [],
        onTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.value = value
        self.unit = unit
        self.history = history
        self.onTap = onTap
    }

    public var body: some View {
        HACard {
            VStack(alignment: .leading, spacing: .zero) {
                header
                if history.count > 1 {
                    // Flush to the card's edges: the frontend's graph footer bleeds to the sides,
                    // which is what makes it read as a footer rather than as another row.
                    HASparkline(values: history, color: color, height: 60)
                }
            }
        }
        .modify { view in
            if let onTap {
                Button(action: onTap) { view }.buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text(unit.map { "\(value) \($0)" } ?? value))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            HStack(alignment: .top) {
                Text(name)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: DesignSystem.Spaces.one)
                if let icon {
                    MaterialDesignIconsImage(icon: icon, size: 24)
                        .foregroundStyle(color)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.half) {
                Text(value)
                    .font(DesignSystem.Font.largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spaces.two)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HASensorCard(
            name: "Kitchen temperature",
            icon: .thermometerIcon,
            value: "21.4",
            unit: "°C",
            history: [18, 18.5, 19.4, 21, 22.3, 21.6, 20.1, 21.4]
        )
        HASensorCard(name: "Humidity", icon: .waterPercentIcon, value: "54", unit: "%")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HASensorCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-sensor-card" }
}

#endif
