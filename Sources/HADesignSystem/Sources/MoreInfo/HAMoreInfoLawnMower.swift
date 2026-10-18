#if !os(watchOS)
import SwiftUI

/// A robot lawn mower's more-info dialog: its state and battery, the illustrated status and its
/// commands. The SwiftUI counterpart of the frontend's `more-info-lawn_mower`.
public struct HAMoreInfoLawnMower: View {
    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let visualState: HARobotVisualState
    private let color: Color
    private let battery: HAMoreInfoBattery?
    private let commands: [HAMoreInfoCommand]

    /// - Parameters:
    ///   - battery: The device's battery, when it has one.
    ///   - commands: Start or pause, stop and dock, as supported.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        visualState: HARobotVisualState,
        color: Color,
        battery: HAMoreInfoBattery? = nil,
        commands: [HAMoreInfoCommand]
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        self.visualState = visualState
        self.color = color
        self.battery = battery
        self.commands = commands
    }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: state, lastChanged: lastChanged, now: now) {
                battery
            }
        } controls: {
            HAStateControlLawnMowerStatus(state: visualState, color: color)
            if !commands.isEmpty {
                HAMoreInfoCommandBar(commands)
            }
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoLawnMower(
            state: "Mowing",
            lastChanged: Date(timeIntervalSinceNow: -600),
            now: Date(),
            visualState: .active,
            color: FrontendColors.stateLawnMowerActiveColor.color,
            battery: HAMoreInfoBattery(level: 72),
            commands: [
                HAMoreInfoCommand(id: "pause", icon: .pauseIcon, label: "Pause") {},
                HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {},
                HAMoreInfoCommand(id: "dock", icon: .homeImportOutlineIcon, label: "Dock") {},
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoLawnMower: FrontendComponent {
    public static var frontendComponentName: String { "more-info-lawn_mower" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
