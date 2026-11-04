#if !os(watchOS)
import HAIconic
import SwiftUI

/// A fan's more-info dialog: its speed as named steps or a percentage, or a plain on/off switch for
/// a fan with no speeds, and the preset, direction and oscillation pickers. The SwiftUI counterpart
/// of the frontend's `more-info-fan`.
public struct HAMoreInfoFan: View {
    /// How the fan's speed is set.
    public enum Speed {
        /// No speeds: an on/off switch.
        case toggle
        /// A few named or numbered steps ("Off · Low · Medium · High"), fastest at the top.
        case steps([HAControlSelectOption], selection: Binding<String?>)
        /// A percentage, for a fan with more steps than fit as buttons.
        case percentage(Binding<Double>, step: Double = 1, powerLabel: String? = nil)
    }

    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let speed: Speed
    private let color: Color
    private let isUnavailable: Bool
    private let selects: [HAMoreInfoSelect]
    @Binding private var isOn: Bool

    /// - Parameters:
    ///   - state: The header: the speed as a percentage while on, else the state.
    ///   - speed: Steps when the fan has few enough speeds to name, as `computeFanSpeeds` decides.
    ///     A `percentage` with a `powerLabel` adds the power button the frontend shows for a fan
    ///     that can be switched off as well as slowed down.
    ///   - selects: Preset, direction and oscillation, as supported.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        isOn: Binding<Bool>,
        speed: Speed,
        color: Color,
        isUnavailable: Bool = false,
        selects: [HAMoreInfoSelect] = []
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        _isOn = isOn
        self.speed = speed
        self.color = color
        self.isUnavailable = isUnavailable
        self.selects = selects
    }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: state, lastChanged: lastChanged, now: now)
        } controls: {
            switch speed {
            case .toggle:
                HAStateControlToggle(
                    isOn: $isOn,
                    onColor: color,
                    iconOn: .fanIcon,
                    iconOff: .fanOffIcon,
                    isDisabled: isUnavailable
                )
            case let .steps(options, selection):
                HAControlSelect(
                    options: options,
                    selection: selection,
                    vertical: true,
                    isDisabled: isUnavailable,
                    tint: color,
                    trackColor: color,
                    thickness: DesignSystem.StateControl.thickness,
                    cornerRadius: DesignSystem.StateControl.cornerRadius,
                    iconSize: DesignSystem.StateControl.iconSize
                )
                .frame(height: DesignSystem.StateControl.length)
            case let .percentage(value, step, powerLabel):
                HAStateControlSlider(
                    value: value,
                    scale: HASliderScale(min: 0, max: 100, step: step),
                    color: color,
                    showsHandle: isOn,
                    isDisabled: isUnavailable
                )
                if let powerLabel {
                    HAOutlinedIconButton(icon: .powerIcon, label: powerLabel, isDisabled: isUnavailable) {
                        isOn.toggle()
                    }
                }
            }
        } footer: {
            HAMoreInfoControlSelectContainer(selects: selects)
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoFan(
            state: "67%",
            lastChanged: Date(timeIntervalSinceNow: -2340),
            now: Date(),
            isOn: .constant(true),
            speed: .steps(
                [
                    .init(id: "high", label: "High", icon: .fanSpeed3Icon),
                    .init(id: "medium", label: "Medium", icon: .fanSpeed2Icon),
                    .init(id: "low", label: "Low", icon: .fanSpeed1Icon),
                    .init(id: "off", label: "Off", icon: .fanOffIcon),
                ],
                selection: .constant("medium")
            ),
            color: FrontendColors.stateFanActiveColor.color,
            selects: [
                HAMoreInfoSelect(
                    id: "oscillating",
                    label: "Oscillating",
                    icon: .arrowOscillatingOffIcon,
                    options: [
                        .init(id: "true", label: "Yes", icon: .arrowOscillatingIcon),
                        .init(id: "false", label: "No", icon: .arrowOscillatingOffIcon),
                    ],
                    selection: .constant("false")
                ),
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoFan: FrontendComponent {
    public static var frontendComponentName: String { "more-info-fan" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
