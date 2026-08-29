#if !os(watchOS)
import SwiftUI

/// A thermostat: the dial with the target on it, the room's reading, and the mode controls beneath.
/// The SwiftUI counterpart of the frontend's `hui-thermostat-card`.
///
/// Composes ``HAControlCircularSlider``; the card's own job is the labels around it and the layout.
public struct HAThermostatCard<Features: View>: View {
    private let name: String
    private let scale: HACircularSliderScale
    private let current: Double?
    private let unit: String
    private let action: String?
    private let showsCurrentAsPrimary: Bool
    private let isDisabled: Bool
    @Binding private var low: Double
    @Binding private var high: Double
    private let isDual: Bool
    private let features: Features

    /// A thermostat with one target.
    ///
    /// - Parameters:
    ///   - action: What it is doing now — "Heating", "Idle" — under the number.
    ///   - showsCurrentAsPrimary: Leads with the room's reading instead of the target, the
    ///     frontend's `show_current_as_primary`.
    public init(
        name: String,
        target: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(min: 7, max: 35, step: 0.5),
        current: Double? = nil,
        unit: String = "°C",
        action: String? = nil,
        showsCurrentAsPrimary: Bool = false,
        isDisabled: Bool = false,
        @ViewBuilder features: () -> Features
    ) {
        _low = target
        _high = target
        self.isDual = false
        self.name = name
        self.scale = scale
        self.current = current
        self.unit = unit
        self.action = action
        self.showsCurrentAsPrimary = showsCurrentAsPrimary
        self.isDisabled = isDisabled
        self.features = features()
    }

    /// A thermostat with a low and a high target, for heat/cool mode.
    public init(
        name: String,
        low: Binding<Double>,
        high: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(min: 7, max: 35, step: 0.5),
        current: Double? = nil,
        unit: String = "°C",
        action: String? = nil,
        showsCurrentAsPrimary: Bool = false,
        isDisabled: Bool = false,
        @ViewBuilder features: () -> Features
    ) {
        _low = low
        _high = high
        self.isDual = true
        self.name = name
        self.scale = scale
        self.current = current
        self.unit = unit
        self.action = action
        self.showsCurrentAsPrimary = showsCurrentAsPrimary
        self.isDisabled = isDisabled
        self.features = features()
    }

    /// The big number in the middle of the dial: the target normally, the reading when the caller
    /// asks for it, and the pair when there are two targets.
    private var primaryText: String {
        if showsCurrentAsPrimary, let current {
            return "\(current.formatted())"
        }
        return isDual
            ? "\(scale.stepped(low).formatted())–\(scale.stepped(high).formatted())"
            : scale.stepped(low).formatted()
    }

    private var secondaryText: String? {
        if showsCurrentAsPrimary {
            return isDual ? nil : "\(scale.stepped(low).formatted()) \(unit)"
        }
        return current.map { "\($0.formatted()) \(unit)" }
    }

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.two) {
                Text(name)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                ZStack {
                    dial
                    VStack(spacing: .zero) {
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.micro) {
                            Text(primaryText)
                                .font(.system(size: 40, weight: .medium))
                            Text(unit)
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

    @ViewBuilder
    private var dial: some View {
        if isDual {
            HAControlCircularSlider(
                low: $low,
                high: $high,
                scale: scale,
                current: current,
                isDisabled: isDisabled
            )
        } else {
            HAControlCircularSlider(
                value: $low,
                scale: scale,
                current: current,
                isDisabled: isDisabled
            )
        }
    }
}

public extension HAThermostatCard where Features == EmptyView {
    /// A thermostat with no controls under the dial.
    init(
        name: String,
        target: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(min: 7, max: 35, step: 0.5),
        current: Double? = nil,
        unit: String = "°C",
        action: String? = nil,
        showsCurrentAsPrimary: Bool = false,
        isDisabled: Bool = false
    ) {
        self.init(
            name: name,
            target: target,
            scale: scale,
            current: current,
            unit: unit,
            action: action,
            showsCurrentAsPrimary: showsCurrentAsPrimary,
            isDisabled: isDisabled,
            features: { EmptyView() }
        )
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAThermostatCard(name: "Living room", target: .constant(21), current: 19, action: "Heating")
        HAThermostatCard(
            name: "Bedroom",
            low: .constant(18),
            high: .constant(24),
            current: 21,
            action: "Idle"
        ) {
            HAControlSelect(
                options: [
                    .init(id: "off", label: "Off", icon: .powerIcon),
                    .init(id: "heat", label: "Heat", icon: .fireIcon),
                    .init(id: "cool", label: "Cool", icon: .snowflakeIcon),
                ],
                selection: .constant("heat"),
                hidesOptionLabels: true
            )
        }
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAThermostatCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-thermostat-card" }
}

#endif
