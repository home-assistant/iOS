#if !os(watchOS)
import SwiftUI

/// A row of square command buttons under a robot's status: start, stop, dock, locate.
///
/// Frontend counterpart: the `.buttons ha-control-button-group` that `more-info-vacuum` and
/// `more-info-lawn_mower` both render from their supported features.
public struct HAMoreInfoCommandBar: View {
    private let commands: [HAMoreInfoCommand]

    public init(_ commands: [HAMoreInfoCommand]) {
        self.commands = commands
    }

    public var body: some View {
        HAControlButtonGroup {
            ForEach(commands) { command in
                HAControlButton(
                    icon: command.icon,
                    label: command.label,
                    isDisabled: command.isDisabled,
                    action: command.action
                )
            }
        }
        .padding(.bottom, DesignSystem.Spaces.oneAndHalf)
    }
}

#Preview {
    HAMoreInfoCommandBar([
        HAMoreInfoCommand(id: "start", icon: .playIcon, label: "Start") {},
        HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop", isDisabled: true) {},
        HAMoreInfoCommand(id: "dock", icon: .homeImportOutlineIcon, label: "Return to dock") {},
    ])
    .padding()
}

extension HAMoreInfoCommandBar: FrontendComponent {
    public static var frontendComponentName: String { "more-info-vacuum" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
