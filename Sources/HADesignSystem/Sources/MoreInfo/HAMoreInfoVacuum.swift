#if !os(watchOS)
import HAIconic
import SwiftUI

/// A robot vacuum's more-info dialog: its state and battery, the illustrated status, its commands
/// and the fan-speed picker, with an entry into cleaning by area. The SwiftUI counterpart of the
/// frontend's `more-info-vacuum`.
public struct HAMoreInfoVacuum: View {
    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let visualState: HARobotVisualState
    private let color: Color
    private let battery: HAMoreInfoBattery?
    private let commands: [HAMoreInfoCommand]
    private let selects: [HAMoreInfoSelect]
    private let isUnavailable: Bool
    private let onCleanAreas: (() -> Void)?

    /// - Parameters:
    ///   - battery: The device's battery, when it has one.
    ///   - commands: Start or pause, stop, return to dock, locate and spot clean, as supported.
    ///   - selects: The fan-speed picker, when it has speeds.
    ///   - onCleanAreas: Adds the clean-by-area entry, for a vacuum supporting `CLEAN_AREA`.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        visualState: HARobotVisualState,
        color: Color,
        battery: HAMoreInfoBattery? = nil,
        commands: [HAMoreInfoCommand],
        selects: [HAMoreInfoSelect] = [],
        isUnavailable: Bool = false,
        onCleanAreas: (() -> Void)? = nil
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        self.visualState = visualState
        self.color = color
        self.battery = battery
        self.commands = commands
        self.selects = selects
        self.isUnavailable = isUnavailable
        self.onCleanAreas = onCleanAreas
    }

    private var strings: HADesignSystemEnvironment.Strings { HADesignSystemEnvironment.current.strings }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: state, lastChanged: lastChanged, now: now) {
                battery
            }
        } controls: {
            HAStateControlVacuumStatus(state: visualState, color: color)
            if !commands.isEmpty {
                HAMoreInfoCommandBar(commands)
            }
        } footer: {
            if !selects.isEmpty || onCleanAreas != nil {
                HAMoreInfoControlSelectContainer(selects: selects) {
                    if let onCleanAreas {
                        Button(action: onCleanAreas) {
                            HStack(spacing: DesignSystem.Spaces.oneAndMicro) {
                                MaterialDesignIconsImage(icon: .textureBoxIcon, size: 20)
                                VStack(alignment: .leading, spacing: .zero) {
                                    Text(strings.vacuumCleaning)
                                        .font(.system(size: 12))
                                    Text(strings.vacuumByArea)
                                        .font(.system(size: 14))
                                }
                                .lineLimit(1)
                                MaterialDesignIconsImage(icon: .chevronRightIcon, size: 20)
                            }
                            .padding(.horizontal, DesignSystem.Spaces.oneAndMicro)
                            .frame(minWidth: 120, minHeight: 48, maxHeight: 48)
                            .background(Color.haDisabled.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
                        }
                        .buttonStyle(.plain)
                        .disabled(isUnavailable)
                        .fixedSize()
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoVacuum(
            state: "Cleaning bedroom",
            lastChanged: Date(timeIntervalSinceNow: -2460),
            now: Date(),
            visualState: .active,
            color: FrontendColors.stateVacuumActiveColor.color,
            battery: HAMoreInfoBattery(level: 64),
            commands: [
                HAMoreInfoCommand(id: "pause", icon: .pauseIcon, label: "Pause") {},
                HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {},
                HAMoreInfoCommand(id: "dock", icon: .homeImportOutlineIcon, label: "Return to dock") {},
                HAMoreInfoCommand(id: "locate", icon: .mapMarkerIcon, label: "Locate") {},
                HAMoreInfoCommand(id: "spot", icon: .targetVariantIcon, label: "Clean spot") {},
            ],
            selects: [
                HAMoreInfoSelect(
                    id: "fan_speed",
                    label: "Fan speed",
                    icon: .fanIcon,
                    options: [.init(id: "turbo", label: "turbo")],
                    selection: .constant("turbo")
                ),
            ],
            onCleanAreas: {}
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoVacuum: FrontendComponent {
    public static var frontendComponentName: String { "more-info-vacuum" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
