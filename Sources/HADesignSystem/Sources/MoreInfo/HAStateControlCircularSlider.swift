#if !os(watchOS)
import HAIconic
import SwiftUI

/// The large dial a climate-style more-info dialog is built around: ``HAControlCircularSlider`` with
/// what it is doing written over it, the target in big numbers, a secondary line, a glow in the
/// colour of the current action and minus/plus buttons along the bottom.
///
/// Frontend counterpart: `state-control-circular-slider-style.ts`, the layout shared by
/// `ha-state-control-climate-temperature`, `ha-state-control-climate-humidity`,
/// `ha-state-control-humidifier-humidity` and `ha-state-control-water_heater-temperature`. Those
/// four differ only in what they put in it, which is the caller's mapping from entity state.
public struct HAStateControlCircularSlider: View {
    /// What the dial sets.
    public enum Target: Equatable {
        /// One value; `mode` is which side of it is coloured.
        case single(mode: HAControlCircularSlider.Mode)
        /// A low and a high value, for heat/cool.
        case dual
        /// Nothing: the dial only shows the reading, with `state` in its middle.
        case none
    }

    private let target: Target
    private let scale: HACircularSliderScale
    private let current: Double?
    private let color: Color
    private let highColor: Color
    private let isInactive: Bool
    private let isDisabled: Bool
    private let label: String?
    private let labelColor: Color?
    private let state: String?
    private let secondary: String?
    private let secondaryIcon: MaterialDesignIcons?
    private let unit: String
    private let unitPosition: HABigNumber.UnitPosition
    private let fractionLength: Int
    private let diameter: CGFloat
    @Binding private var low: Double
    @Binding private var high: Double
    @State private var adjustsHigh = false

    /// A dial with one target.
    ///
    /// - Parameters:
    ///   - label: What the entity is doing, over the number: "Heating", "Target".
    ///   - labelColor: The action's colour, which also tints the glow. `nil` when idle.
    ///   - secondary: The line under the number, such as the room's reading.
    ///   - fractionLength: Decimals in the big number, from the entity's step.
    public init(
        value: Binding<Double>,
        scale: HACircularSliderScale,
        mode: HAControlCircularSlider.Mode = .start,
        current: Double? = nil,
        color: Color,
        isInactive: Bool = false,
        isDisabled: Bool = false,
        label: String? = nil,
        labelColor: Color? = nil,
        secondary: String? = nil,
        secondaryIcon: MaterialDesignIcons? = nil,
        unit: String,
        unitPosition: HABigNumber.UnitPosition = .top,
        fractionLength: Int = 0,
        diameter: CGFloat = DesignSystem.StateControl.dialDiameter
    ) {
        _low = value
        _high = value
        self.target = .single(mode: mode)
        self.scale = scale
        self.current = current
        self.color = color
        self.highColor = color
        self.isInactive = isInactive
        self.isDisabled = isDisabled
        self.label = label
        self.labelColor = labelColor
        self.state = nil
        self.secondary = secondary
        self.secondaryIcon = secondaryIcon
        self.unit = unit
        self.unitPosition = unitPosition
        self.fractionLength = fractionLength
        self.diameter = diameter
    }

    /// A dial with a low and a high target. Tapping either number picks which one the buttons move.
    public init(
        low: Binding<Double>,
        high: Binding<Double>,
        scale: HACircularSliderScale,
        current: Double? = nil,
        lowColor: Color,
        highColor: Color,
        isInactive: Bool = false,
        isDisabled: Bool = false,
        label: String? = nil,
        labelColor: Color? = nil,
        secondary: String? = nil,
        secondaryIcon: MaterialDesignIcons? = nil,
        unit: String,
        fractionLength: Int = 0,
        diameter: CGFloat = DesignSystem.StateControl.dialDiameter
    ) {
        _low = low
        _high = high
        self.target = .dual
        self.scale = scale
        self.current = current
        self.color = lowColor
        self.highColor = highColor
        self.isInactive = isInactive
        self.isDisabled = isDisabled
        self.label = label
        self.labelColor = labelColor
        self.state = nil
        self.secondary = secondary
        self.secondaryIcon = secondaryIcon
        self.unit = unit
        self.unitPosition = .top
        self.fractionLength = fractionLength
        self.diameter = diameter
    }

    /// A dial with nothing to set: the whole ring in `color`, the reading marked on it and `state`
    /// written in the middle: the frontend's read-only `mode="full"`.
    public init(
        state: String?,
        scale: HACircularSliderScale,
        current: Double? = nil,
        color: Color,
        isInactive: Bool = false,
        isDisabled: Bool = false,
        label: String? = nil,
        labelColor: Color? = nil,
        secondary: String? = nil,
        secondaryIcon: MaterialDesignIcons? = nil,
        diameter: CGFloat = DesignSystem.StateControl.dialDiameter
    ) {
        _low = .constant(scale.min)
        _high = .constant(scale.max)
        self.target = .none
        self.scale = scale
        self.current = current
        self.color = color
        self.highColor = color
        self.isInactive = isInactive
        self.isDisabled = isDisabled
        self.label = label
        self.labelColor = labelColor
        self.state = state
        self.secondary = secondary
        self.secondaryIcon = secondaryIcon
        self.unit = ""
        self.unitPosition = .top
        self.fractionLength = 0
        self.diameter = diameter
    }

    private var bigNumberSize: CGFloat { diameter * 57 / 320 }
    private var buttonsColor: Color? {
        guard target == .dual, !isInactive else { return nil }
        return adjustsHigh ? highColor : color
    }

    public var body: some View {
        ZStack {
            RadialGradient(
                colors: [labelColor ?? .clear, .clear],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.6
            )
            .opacity(0.15)
            .frame(width: diameter * 1.2, height: diameter * 1.2)
            .allowsHitTesting(false)

            switch target {
            case let .single(mode):
                HAControlCircularSlider(
                    value: $low,
                    scale: scale,
                    current: current,
                    mode: mode,
                    isDisabled: isDisabled,
                    isInactive: isInactive,
                    diameter: diameter,
                    activeColor: color,
                    label: label
                )
            case .dual:
                HAControlCircularSlider(
                    low: $low,
                    high: $high,
                    scale: scale,
                    current: current,
                    isDisabled: isDisabled,
                    isInactive: isInactive,
                    diameter: diameter,
                    activeColor: color,
                    highColor: highColor,
                    label: label
                )
            case .none:
                HAControlCircularSlider(
                    value: .constant(scale.min),
                    scale: scale,
                    current: current,
                    mode: .full,
                    isDisabled: isDisabled || isInactive,
                    isReadOnly: true,
                    diameter: diameter,
                    activeColor: color,
                    label: label
                )
            }

            VStack(spacing: DesignSystem.Spaces.one) {
                Text(label ?? " ")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isDisabled ? Color.secondary : labelColor ?? Color(uiColor: .label))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: diameter * 0.6)
                primary
                HStack(spacing: DesignSystem.Spaces.half) {
                    if let secondaryIcon, secondary != nil {
                        MaterialDesignIconsImage(icon: secondaryIcon, size: 16)
                    }
                    Text(secondary ?? " ")
                }
                .font(.system(size: 16, weight: .medium))
            }
            .allowsHitTesting(target == .dual)

            if target != .none, !isDisabled {
                HStack(spacing: DesignSystem.Spaces.three) {
                    HAOutlinedIconButton(
                        icon: .minusIcon,
                        label: HADesignSystemEnvironment.current.strings.decrease,
                        outlineColor: buttonsColor
                    ) {
                        step(by: -scale.step)
                    }
                    HAOutlinedIconButton(
                        icon: .plusIcon,
                        label: HADesignSystemEnvironment.current.strings.increase,
                        outlineColor: buttonsColor
                    ) {
                        step(by: scale.step)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, DesignSystem.Spaces.oneAndMicro)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var primary: some View {
        switch target {
        case .single:
            HABigNumber(
                value: scale.stepped(low),
                unit: unit,
                unitPosition: unitPosition,
                fractionLength: fractionLength,
                size: bigNumberSize
            )
        case .dual:
            HStack(spacing: DesignSystem.Spaces.three) {
                targetButton(value: low, isSelected: !adjustsHigh) { adjustsHigh = false }
                targetButton(value: high, isSelected: adjustsHigh) { adjustsHigh = true }
            }
        case .none:
            if let state {
                Text(state)
                    .font(.system(size: 36))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private func targetButton(value: Double, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HABigNumber(value: scale.stepped(value), unit: unit, fractionLength: fractionLength, size: bigNumberSize)
                .opacity(isSelected ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func step(by delta: Double) {
        switch target {
        case .single:
            low = Swift.min(Swift.max(scale.stepped(low + delta), scale.min), scale.max)
            high = low
        case .dual where adjustsHigh:
            high = Swift.min(Swift.max(scale.stepped(high + delta), low), scale.max)
        case .dual:
            low = Swift.min(Swift.max(scale.stepped(low + delta), scale.min), high)
        case .none:
            break
        }
    }
}

#Preview("Single") {
    HAStateControlCircularSlider(
        value: .constant(20),
        scale: HACircularSliderScale(min: 10, max: 30, step: 0.5),
        current: 18,
        color: FrontendColors.stateClimateHeatColor.color,
        label: "Preheating",
        labelColor: FrontendColors.stateClimateHeatColor.color,
        unit: "°C",
        fractionLength: 1
    )
    .padding()
}

#Preview("Dual") {
    HAStateControlCircularSlider(
        low: .constant(20),
        high: .constant(25),
        scale: HACircularSliderScale(min: 10, max: 30, step: 1),
        current: 18,
        lowColor: FrontendColors.stateClimateHeatColor.color,
        highColor: FrontendColors.stateClimateCoolColor.color,
        label: "Heating",
        labelColor: FrontendColors.stateClimateHeatColor.color,
        unit: "°C"
    )
    .padding()
}

#Preview("Read only") {
    HAStateControlCircularSlider(
        state: "Fan only",
        scale: HACircularSliderScale(min: 0, max: 1, step: 1),
        color: FrontendColors.stateClimateFanOnlyColor.color,
        label: "Fan",
        labelColor: FrontendColors.stateClimateFanOnlyColor.color
    )
    .padding()
}

extension HAStateControlCircularSlider: FrontendComponent {
    public static var frontendComponentName: String { "ha-state-control-climate-temperature" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
