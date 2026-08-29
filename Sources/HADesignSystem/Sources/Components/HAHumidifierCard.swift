#if !os(watchOS)
import SwiftUI

/// A humidifier: the dial with the target humidity on it, the room's reading, and the mode controls
/// beneath. The SwiftUI counterpart of the frontend's `hui-humidifier-card`.
///
/// The thermostat card's shape with a humidity range and a green dial — the frontend keeps them as
/// separate cards for the same reason, since what they read and the colour they read it in differ
/// even though the furniture is identical.
public struct HAHumidifierCard<Features: View>: View {
    private let name: String
    private let scale: HACircularSliderScale
    private let current: Double?
    private let action: String?
    private let showsCurrentAsPrimary: Bool
    private let isDisabled: Bool
    @Binding private var target: Double
    private let features: Features

    public init(
        name: String,
        target: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(min: 0, max: 100, step: 1),
        current: Double? = nil,
        action: String? = nil,
        showsCurrentAsPrimary: Bool = false,
        isDisabled: Bool = false,
        @ViewBuilder features: () -> Features
    ) {
        _target = target
        self.name = name
        self.scale = scale
        self.current = current
        self.action = action
        self.showsCurrentAsPrimary = showsCurrentAsPrimary
        self.isDisabled = isDisabled
        self.features = features()
    }

    private var primaryText: String {
        if showsCurrentAsPrimary, let current {
            return current.formatted()
        }
        return scale.stepped(target).formatted()
    }

    private var secondaryText: String? {
        showsCurrentAsPrimary
            ? "\(scale.stepped(target).formatted()) %"
            : current.map { "\($0.formatted()) %" }
    }

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.two) {
                Text(name)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                ZStack {
                    HAControlCircularSlider(
                        value: $target,
                        scale: scale,
                        current: current,
                        isDisabled: isDisabled,
                        activeColor: .haSuccessColor
                    )
                    VStack(spacing: .zero) {
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.micro) {
                            Text(primaryText)
                                .font(.system(size: 40, weight: .medium))
                            Text("%")
                                .font(DesignSystem.Font.body)
                                .foregroundStyle(.secondary)
                        }
                        if let secondaryText {
                            Text(secondaryText)
                                .font(DesignSystem.Font.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let action {
                            Text(action)
                                .font(DesignSystem.Font.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                features
            }
            .padding(DesignSystem.Spaces.two)
        }
        .accessibilityElement(children: .contain)
    }
}

public extension HAHumidifierCard where Features == EmptyView {
    /// A humidifier with no controls under the dial.
    init(
        name: String,
        target: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(min: 0, max: 100, step: 1),
        current: Double? = nil,
        action: String? = nil,
        showsCurrentAsPrimary: Bool = false,
        isDisabled: Bool = false
    ) {
        self.init(
            name: name,
            target: target,
            scale: scale,
            current: current,
            action: action,
            showsCurrentAsPrimary: showsCurrentAsPrimary,
            isDisabled: isDisabled,
            features: { EmptyView() }
        )
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAHumidifierCard(name: "Bedroom", target: .constant(55), current: 48, action: "Humidifying")
        HAHumidifierCard(name: "Study", target: .constant(60), current: 62, showsCurrentAsPrimary: true)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAHumidifierCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-humidifier-card" }
}

#endif
