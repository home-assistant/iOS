#if !os(watchOS)
import HAIconic
import SwiftUI

/// The tall on/off switch a more-info dialog shows for an entity with nothing finer to set: a light
/// without brightness, a fan without speeds, a lock, a cover that only opens and closes. The SwiftUI
/// counterpart of the frontend's `ha-state-control-toggle`.
///
/// When the entity's state cannot be trusted (`assumed_state`, or simply unknown), a switch would
/// claim a position nobody knows, so it becomes two buttons instead, as the frontend does.
public struct HAStateControlToggle: View {
    private let onColor: Color
    private let offColor: Color
    private let iconOn: MaterialDesignIcons
    private let iconOff: MaterialDesignIcons
    private let onLabel: String
    private let offLabel: String
    private let isAssumedState: Bool
    private let isDisabled: Bool
    @Binding private var isOn: Bool

    /// - Parameters:
    ///   - isAssumedState: Splits the switch into on and off buttons.
    ///   - onLabel: Names the on button, and the switch while it is off. Defaults to "Turn on".
    ///   - offLabel: Names the off button, and the switch while it is on. Defaults to "Turn off".
    public init(
        isOn: Binding<Bool>,
        onColor: Color,
        offColor: Color = .haDisabled,
        iconOn: MaterialDesignIcons = .flashIcon,
        iconOff: MaterialDesignIcons = .flashOffIcon,
        onLabel: String = HADesignSystemEnvironment.current.strings.turnOn,
        offLabel: String = HADesignSystemEnvironment.current.strings.turnOff,
        isAssumedState: Bool = false,
        isDisabled: Bool = false
    ) {
        _isOn = isOn
        self.onColor = onColor
        self.offColor = offColor
        self.iconOn = iconOn
        self.iconOff = iconOff
        self.onLabel = onLabel
        self.offLabel = offLabel
        self.isAssumedState = isAssumedState
        self.isDisabled = isDisabled
    }

    public var body: some View {
        if isAssumedState {
            VStack(spacing: DesignSystem.StateControl.padding) {
                HAControlButton(
                    icon: iconOn,
                    label: onLabel,
                    isDisabled: isDisabled,
                    size: nil,
                    cornerRadius: DesignSystem.StateControl.cornerRadius,
                    iconSize: DesignSystem.StateControl.iconSize,
                    activeColor: isOn ? onColor : nil
                ) {
                    isOn = true
                }
                HAControlButton(
                    icon: iconOff,
                    label: offLabel,
                    isDisabled: isDisabled,
                    size: nil,
                    cornerRadius: DesignSystem.StateControl.cornerRadius,
                    iconSize: DesignSystem.StateControl.iconSize,
                    activeColor: isOn ? nil : offColor
                ) {
                    isOn = false
                }
            }
            .padding(DesignSystem.StateControl.padding)
            .frame(width: DesignSystem.StateControl.thickness, height: DesignSystem.StateControl.length)
        } else {
            HAControlSwitch(
                isOn: $isOn,
                vertical: true,
                reversed: true,
                iconOn: iconOn,
                iconOff: iconOff,
                isDisabled: isDisabled,
                label: isOn ? offLabel : onLabel,
                onColor: onColor,
                offColor: offColor,
                thickness: DesignSystem.StateControl.thickness,
                cornerRadius: DesignSystem.StateControl.cornerRadius,
                padding: DesignSystem.StateControl.padding,
                iconSize: DesignSystem.StateControl.iconSize
            )
            .frame(height: DesignSystem.StateControl.length)
        }
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.three) {
        HAStateControlToggle(
            isOn: .constant(true),
            onColor: FrontendColors.stateLightActiveColor.color,
            iconOn: .lightbulbOnIcon,
            iconOff: .lightbulbOffIcon
        )
        HAStateControlToggle(
            isOn: .constant(false),
            onColor: FrontendColors.stateSwitchActiveColor.color,
            isAssumedState: true
        )
    }
    .padding()
}

extension HAStateControlToggle: FrontendComponent {
    public static var frontendComponentName: String { "ha-state-control-toggle" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
