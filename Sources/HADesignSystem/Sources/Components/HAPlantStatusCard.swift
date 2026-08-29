#if !os(watchOS)
import SwiftUI

/// How a plant is getting on: its picture, its name, and its readings with the unhappy ones marked.
/// The SwiftUI counterpart of the frontend's `hui-plant-status-card`.
///
/// The readings sit **side by side**, each a centred column of icon, value and unit — the frontend's
/// `.content` is a `space-between` row of `.attributes` columns, not a list of rows.
///
/// A problem colours and bolds the *value* only. The icon keeps its normal tint: it says which
/// reading this is, and recolouring it would make the row harder to scan rather than easier.
public struct HAPlantStatusCard: View {
    private static let bannerHeight: CGFloat = 140
    /// `rgba(0, 0, 0, var(--dark-secondary-opacity))` — a flat band behind the name, not a gradient.
    private static let bannerScrimOpacity: Double = 0.54

    private let name: String
    private let picture: Image?
    private let attributes: [HAPlantAttribute]
    private let onTap: (() -> Void)?

    public init(
        name: String,
        picture: Image? = nil,
        attributes: [HAPlantAttribute],
        onTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.picture = picture
        self.attributes = attributes
        self.onTap = onTap
    }

    public var body: some View {
        HACard {
            VStack(alignment: .leading, spacing: .zero) {
                if let picture {
                    banner(picture)
                } else {
                    Text(name)
                        .font(DesignSystem.Font.title2)
                        .padding(.horizontal, DesignSystem.Spaces.two)
                        .padding(.top, DesignSystem.Spaces.oneAndHalf)
                }
                readings
            }
        }
        .modify { view in
            if let onTap {
                Button(action: onTap) { view }.buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(name))
    }

    private func banner(_ picture: Image) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .overlay {
                    picture
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
            Text(name)
                .font(DesignSystem.Font.headline)
                .foregroundStyle(.white)
                .padding(DesignSystem.Spaces.two)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(Self.bannerScrimOpacity))
        }
        .frame(height: Self.bannerHeight)
        .frame(maxWidth: .infinity)
    }

    /// `.content`: the readings spread across the card's width, each centred under its own icon.
    private var readings: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            ForEach(attributes) { attribute in
                column(attribute)
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.four)
        .padding(.top, DesignSystem.Spaces.two)
        .padding(.bottom, picture == nil ? DesignSystem.Spaces.three : DesignSystem.Spaces.two)
    }

    private func column(_ attribute: HAPlantAttribute) -> some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            MaterialDesignIconsImage(icon: attribute.icon, size: 24)
                .foregroundStyle(.secondary)
            Text(attribute.value)
                .font(DesignSystem.Font.body)
                .fontWeight(attribute.isProblem ? .bold : .regular)
                .foregroundStyle(attribute.isProblem ? Color.haErrorColor : .primary)
            if let unit = attribute.unit {
                Text(unit)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAPlantStatusCard(
            name: "Monstera",
            attributes: [
                .init(id: "moisture", icon: .waterPercentIcon, value: "18", unit: "%", isProblem: true),
                .init(id: "temperature", icon: .thermometerIcon, value: "21.4", unit: "°C"),
                .init(id: "battery", icon: .batteryIcon, value: "88", unit: "%"),
            ]
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAPlantStatusCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-plant-status-card" }
}
#endif
