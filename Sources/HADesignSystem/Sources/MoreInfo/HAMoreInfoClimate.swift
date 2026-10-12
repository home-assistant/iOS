#if !os(watchOS)
import HAIconic
import SwiftUI

/// A thermostat's more-info dialog: the room's readings, the temperature dial, a switch to the
/// humidity dial when the thermostat sets humidity too, and its mode pickers. The SwiftUI
/// counterpart of the frontend's `more-info-climate`.
public struct HAMoreInfoClimate: View {
    /// What the temperature dial sets.
    public enum Target {
        /// One temperature; `mode` is `.end` when cooling down to it.
        case single(Binding<Double>, mode: HAControlCircularSlider.Mode = .start)
        /// A low and a high temperature, for heat/cool.
        case range(low: Binding<Double>, high: Binding<Double>)
        /// No target, as for a fan-only mode: the dial shows the state instead.
        case none(state: String)
    }

    /// The humidity dial a thermostat with `TARGET_HUMIDITY` can switch to.
    public struct Humidity {
        public let target: Binding<Double>
        public let scale: HACircularSliderScale
        public let current: Double?
        public let color: Color
        public let label: String
        public let temperatureToggleLabel: String
        public let humidityToggleLabel: String

        /// - Parameters:
        ///   - label: Over the number, "Target humidity".
        ///   - temperatureToggleLabel: Names the toggle back to the temperature dial.
        public init(
            target: Binding<Double>,
            scale: HACircularSliderScale = HACircularSliderScale(min: 0, max: 100, step: 1),
            current: Double? = nil,
            color: Color,
            label: String,
            temperatureToggleLabel: String,
            humidityToggleLabel: String
        ) {
            self.target = target
            self.scale = scale
            self.current = current
            self.color = color
            self.label = label
            self.temperatureToggleLabel = temperatureToggleLabel
            self.humidityToggleLabel = humidityToggleLabel
        }
    }

    private let readings: [HAMoreInfoReading]
    private let target: Target
    private let scale: HACircularSliderScale
    private let current: Double?
    private let unit: String
    private let fractionLength: Int
    private let color: Color
    private let lowColor: Color
    private let highColor: Color
    private let action: String?
    private let actionColor: Color?
    private let isActive: Bool
    private let isUnavailable: Bool
    private let humidity: Humidity?
    private let selects: [HAMoreInfoSelect]
    @State private var showsHumidity = false

    /// - Parameters:
    ///   - readings: Current temperature and humidity, over the dial.
    ///   - color: The mode's colour, for a single target or none.
    ///   - lowColor: The heating colour a range's low target is drawn in.
    ///   - highColor: The cooling colour a range's high target is drawn in.
    ///   - action: What it is doing ("Heating", "Idle"), or the mode's name when it reports none.
    ///   - actionColor: The colour of what it is doing, which also tints the glow; `nil` when idle.
    ///   - isActive: `false` when off, which leaves only the targets on the dial.
    ///   - selects: Mode, preset, fan mode, swing mode and horizontal swing, as supported.
    public init(
        readings: [HAMoreInfoReading],
        target: Target,
        scale: HACircularSliderScale,
        current: Double? = nil,
        unit: String,
        fractionLength: Int = 1,
        color: Color,
        lowColor: Color = FrontendColors.stateClimateHeatColor.color,
        highColor: Color = FrontendColors.stateClimateCoolColor.color,
        action: String? = nil,
        actionColor: Color? = nil,
        isActive: Bool = true,
        isUnavailable: Bool = false,
        humidity: Humidity? = nil,
        selects: [HAMoreInfoSelect] = []
    ) {
        self.readings = readings
        self.target = target
        self.scale = scale
        self.current = current
        self.unit = unit
        self.fractionLength = fractionLength
        self.color = color
        self.lowColor = lowColor
        self.highColor = highColor
        self.action = action
        self.actionColor = actionColor
        self.isActive = isActive
        self.isUnavailable = isUnavailable
        self.humidity = humidity
        self.selects = selects
    }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoReadings(readings)
        } controls: {
            if let humidity, showsHumidity {
                HAStateControlCircularSlider(
                    value: humidity.target,
                    scale: humidity.scale,
                    current: humidity.current,
                    color: humidity.color,
                    isInactive: !isActive,
                    isDisabled: isUnavailable,
                    label: humidity.label,
                    unit: "%",
                    unitPosition: .bottom
                )
            } else {
                switch target {
                case let .single(value, mode):
                    HAStateControlCircularSlider(
                        value: value,
                        scale: scale,
                        mode: mode,
                        current: current,
                        color: color,
                        isInactive: !isActive,
                        isDisabled: isUnavailable,
                        label: action,
                        labelColor: actionColor,
                        unit: unit,
                        fractionLength: fractionLength
                    )
                case let .range(low, high):
                    HAStateControlCircularSlider(
                        low: low,
                        high: high,
                        scale: scale,
                        current: current,
                        lowColor: isActive ? lowColor : .haDisabled,
                        highColor: isActive ? highColor : .haDisabled,
                        isInactive: !isActive,
                        isDisabled: isUnavailable,
                        label: action,
                        labelColor: actionColor,
                        unit: unit,
                        fractionLength: fractionLength
                    )
                case let .none(state):
                    HAStateControlCircularSlider(
                        state: state,
                        scale: scale,
                        current: current,
                        color: color,
                        isInactive: !isActive,
                        isDisabled: isUnavailable,
                        label: action,
                        labelColor: actionColor
                    )
                }
            }
            if let humidity {
                HAIconButtonGroup {
                    HAIconButtonToggle(
                        icon: .thermometerIcon,
                        label: humidity.temperatureToggleLabel,
                        isSelected: Binding(get: { !showsHumidity }, set: { _ in showsHumidity = false })
                    )
                    HAIconButtonToggle(
                        icon: .waterPercentIcon,
                        label: humidity.humidityToggleLabel,
                        isSelected: Binding(get: { showsHumidity }, set: { _ in showsHumidity = true })
                    )
                }
                .disabled(isUnavailable)
            }
        } footer: {
            HAMoreInfoControlSelectContainer(selects: selects)
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoClimate(
            readings: [
                HAMoreInfoReading(label: "Current temperature", value: "18 °C"),
                HAMoreInfoReading(label: "Current humidity", value: "40 %"),
            ],
            target: .range(low: .constant(20), high: .constant(25)),
            scale: HACircularSliderScale(min: 10, max: 30, step: 1),
            current: 18,
            unit: "°C",
            fractionLength: 0,
            color: FrontendColors.stateClimateHeatCoolColor.color,
            action: "Heating",
            actionColor: FrontendColors.stateClimateHeatColor.color,
            humidity: .init(
                target: .constant(50),
                current: 40,
                color: FrontendColors.stateHumidifierOnColor.color,
                label: "Target humidity",
                temperatureToggleLabel: "Temperature",
                humidityToggleLabel: "Humidity"
            ),
            selects: [
                HAMoreInfoSelect(
                    id: "mode",
                    label: "Mode",
                    icon: .thermostatIcon,
                    options: [.init(id: "auto", label: "Auto", icon: .thermostatAutoIcon)],
                    selection: .constant("auto")
                ),
                HAMoreInfoSelect(
                    id: "preset",
                    label: "Preset",
                    icon: .tuneVariantIcon,
                    options: [.init(id: "eco", label: "Eco", icon: .leafIcon)],
                    selection: .constant("eco")
                ),
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoClimate: FrontendComponent {
    public static var frontendComponentName: String { "more-info-climate" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
