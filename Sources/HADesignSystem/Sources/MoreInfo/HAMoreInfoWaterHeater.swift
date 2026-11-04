#if !os(watchOS)
import SwiftUI

/// A water heater's more-info dialog: the tank's temperature, the target dial and the operation and
/// away mode pickers. The SwiftUI counterpart of the frontend's `more-info-water_heater`.
public struct HAMoreInfoWaterHeater: View {
    private let readings: [HAMoreInfoReading]
    private let target: Binding<Double>?
    private let state: String
    private let targetLabel: String
    private let scale: HACircularSliderScale
    private let current: Double?
    private let unit: String
    private let fractionLength: Int
    private let color: Color
    private let isActive: Bool
    private let isUnavailable: Bool
    private let selects: [HAMoreInfoSelect]

    /// - Parameters:
    ///   - target: The temperature to heat to, or `nil` when it has none; the dial then shows
    ///     `state` alone.
    ///   - targetLabel: Over the number, "Target".
    ///   - selects: Operation mode and away mode, as supported.
    public init(
        readings: [HAMoreInfoReading],
        target: Binding<Double>?,
        state: String,
        targetLabel: String,
        scale: HACircularSliderScale,
        current: Double? = nil,
        unit: String,
        fractionLength: Int = 0,
        color: Color,
        isActive: Bool = true,
        isUnavailable: Bool = false,
        selects: [HAMoreInfoSelect] = []
    ) {
        self.readings = readings
        self.target = target
        self.state = state
        self.targetLabel = targetLabel
        self.scale = scale
        self.current = current
        self.unit = unit
        self.fractionLength = fractionLength
        self.color = color
        self.isActive = isActive
        self.isUnavailable = isUnavailable
        self.selects = selects
    }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoReadings(readings)
        } controls: {
            if let target, !isUnavailable {
                HAStateControlCircularSlider(
                    value: target,
                    scale: scale,
                    current: current,
                    color: color,
                    isInactive: !isActive,
                    label: targetLabel,
                    unit: unit,
                    fractionLength: fractionLength
                )
            } else {
                HAStateControlCircularSlider(
                    state: nil,
                    scale: scale,
                    current: current,
                    color: color,
                    isInactive: !isActive,
                    isDisabled: isUnavailable,
                    label: state
                )
            }
        } footer: {
            HAMoreInfoControlSelectContainer(selects: selects)
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoWaterHeater(
            readings: [HAMoreInfoReading(label: "Current temperature", value: "55 °C")],
            target: .constant(60),
            state: "Eco",
            targetLabel: "Target",
            scale: HACircularSliderScale(min: 45, max: 70, step: 1),
            current: 55,
            unit: "°C",
            color: FrontendColors.stateWaterHeaterEcoColor.color,
            selects: [
                HAMoreInfoSelect(
                    id: "mode",
                    label: "Mode",
                    icon: .waterBoilerIcon,
                    options: [.init(id: "eco", label: "Eco", icon: .leafIcon)],
                    selection: .constant("eco")
                ),
                HAMoreInfoSelect(
                    id: "away",
                    label: "Away mode",
                    icon: .accountIcon,
                    options: [
                        .init(id: "on", label: "On", icon: .accountArrowRightIcon),
                        .init(id: "off", label: "Off", icon: .accountIcon),
                    ],
                    selection: .constant("off")
                ),
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoWaterHeater: FrontendComponent {
    public static var frontendComponentName: String { "more-info-water_heater" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
