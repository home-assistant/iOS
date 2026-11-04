#if !os(watchOS)
import SwiftUI

/// A humidifier's more-info dialog: the room's humidity, the target dial and the on/off and mode
/// pickers. The SwiftUI counterpart of the frontend's `more-info-humidifier`.
public struct HAMoreInfoHumidifier: View {
    private let readings: [HAMoreInfoReading]
    private let target: Binding<Double>?
    private let state: String
    private let scale: HACircularSliderScale
    private let current: Double?
    private let color: Color
    private let action: String?
    private let actionColor: Color?
    private let isActive: Bool
    private let isUnavailable: Bool
    private let selects: [HAMoreInfoSelect]

    /// - Parameters:
    ///   - target: The humidity to reach, or `nil` when the humidifier reports none; the dial then
    ///     shows `state` instead.
    ///   - action: What it is doing ("Humidifying", "Idle"), or the state when it reports none.
    ///   - selects: The on/off picker, and the mode picker when it has modes.
    public init(
        readings: [HAMoreInfoReading],
        target: Binding<Double>?,
        state: String,
        scale: HACircularSliderScale = HACircularSliderScale(min: 0, max: 100, step: 1),
        current: Double? = nil,
        color: Color,
        action: String? = nil,
        actionColor: Color? = nil,
        isActive: Bool = true,
        isUnavailable: Bool = false,
        selects: [HAMoreInfoSelect] = []
    ) {
        self.readings = readings
        self.target = target
        self.state = state
        self.scale = scale
        self.current = current
        self.color = color
        self.action = action
        self.actionColor = actionColor
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
                    label: action,
                    labelColor: actionColor,
                    unit: "%",
                    unitPosition: .bottom
                )
            } else {
                HAStateControlCircularSlider(
                    state: isUnavailable ? nil : state,
                    scale: scale,
                    current: current,
                    color: color,
                    isInactive: !isActive,
                    isDisabled: isUnavailable,
                    label: isUnavailable ? state : action,
                    labelColor: actionColor
                )
            }
        } footer: {
            HAMoreInfoControlSelectContainer(selects: selects)
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoHumidifier(
            readings: [HAMoreInfoReading(label: "Current humidity", value: "45 %")],
            target: .constant(60),
            state: "On",
            current: 45,
            color: FrontendColors.stateHumidifierOnColor.color,
            action: "Humidifying",
            actionColor: FrontendColors.stateHumidifierOnColor.color,
            selects: [
                HAMoreInfoSelect(
                    id: "state",
                    label: "State",
                    icon: .powerIcon,
                    options: [.init(id: "on", label: "On"), .init(id: "off", label: "Off")],
                    selection: .constant("on")
                ),
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoHumidifier: FrontendComponent {
    public static var frontendComponentName: String { "more-info-humidifier" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
