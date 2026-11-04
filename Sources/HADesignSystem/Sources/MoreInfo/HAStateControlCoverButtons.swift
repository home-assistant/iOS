#if !os(watchOS)
import SwiftUI

/// A cover's open, stop and close buttons, stacked; or, for a cover that tilts as well, laid out as
/// a cross with the tilt buttons either side of stop. The SwiftUI counterpart of the frontend's
/// `ha-state-control-cover-buttons`.
public struct HAStateControlCoverButtons: View {
    private let open: HAMoreInfoCommand?
    private let stop: HAMoreInfoCommand?
    private let close: HAMoreInfoCommand?
    private let openTilt: HAMoreInfoCommand?
    private let closeTilt: HAMoreInfoCommand?

    /// Pass only the commands the cover supports; `getCoverLayout` decides from that whether it is a
    /// line or a cross.
    ///
    /// - Parameter stop: Stops both movement and tilt, as the frontend's single stop button does.
    public init(
        open: HAMoreInfoCommand? = nil,
        stop: HAMoreInfoCommand? = nil,
        close: HAMoreInfoCommand? = nil,
        openTilt: HAMoreInfoCommand? = nil,
        closeTilt: HAMoreInfoCommand? = nil
    ) {
        self.open = open
        self.stop = stop
        self.close = close
        self.openTilt = openTilt
        self.closeTilt = closeTilt
    }

    private static var crossCell: CGFloat { 100 }

    private var isCross: Bool {
        (open != nil || close != nil) && (openTilt != nil || closeTilt != nil)
    }

    private var line: [HAMoreInfoCommand] {
        if open != nil || close != nil {
            return [open, stop, close].compactMap { $0 }
        }
        return [openTilt, stop, closeTilt].compactMap { $0 }
    }

    public var body: some View {
        if isCross {
            Grid(
                horizontalSpacing: DesignSystem.StateControl.buttonGroupSpacing,
                verticalSpacing: DesignSystem.StateControl.buttonGroupSpacing
            ) {
                GridRow {
                    Color.clear.frame(width: Self.crossCell, height: Self.crossCell)
                    cell(open)
                    Color.clear.frame(width: Self.crossCell, height: Self.crossCell)
                }
                GridRow {
                    cell(closeTilt)
                    cell(stop)
                    cell(openTilt)
                }
                GridRow {
                    Color.clear.frame(width: Self.crossCell, height: Self.crossCell)
                    cell(close)
                    Color.clear.frame(width: Self.crossCell, height: Self.crossCell)
                }
            }
            .frame(height: DesignSystem.StateControl.length)
        } else {
            HAControlButtonGroup(
                vertical: true,
                thickness: Self.crossCell,
                spacing: DesignSystem.StateControl.buttonGroupSpacing
            ) {
                ForEach(line) { command in
                    button(command)
                }
            }
            .frame(height: DesignSystem.StateControl.length)
        }
    }

    @ViewBuilder
    private func cell(_ command: HAMoreInfoCommand?) -> some View {
        if let command {
            button(command)
                .frame(width: Self.crossCell, height: Self.crossCell)
        } else {
            Color.clear.frame(width: Self.crossCell, height: Self.crossCell)
        }
    }

    private func button(_ command: HAMoreInfoCommand) -> some View {
        HAControlButton(
            icon: command.icon,
            label: command.label,
            isDisabled: command.isDisabled,
            size: nil,
            cornerRadius: DesignSystem.StateControl.cornerRadius,
            iconSize: DesignSystem.StateControl.iconSize,
            action: command.action
        )
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.three) {
        HAStateControlCoverButtons(
            open: HAMoreInfoCommand(id: "open", icon: .arrowUpIcon, label: "Open") {},
            stop: HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {},
            close: HAMoreInfoCommand(id: "close", icon: .arrowDownIcon, label: "Close") {}
        )
        HAStateControlCoverButtons(
            open: HAMoreInfoCommand(id: "open", icon: .arrowUpIcon, label: "Open") {},
            stop: HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {},
            close: HAMoreInfoCommand(id: "close", icon: .arrowDownIcon, label: "Close") {},
            openTilt: HAMoreInfoCommand(id: "open-tilt", icon: .arrowTopRightIcon, label: "Open tilt") {},
            closeTilt: HAMoreInfoCommand(id: "close-tilt", icon: .arrowBottomLeftIcon, label: "Close tilt") {}
        )
        .scaleEffect(0.6)
    }
    .padding()
}

extension HAStateControlCoverButtons: FrontendComponent {
    public static var frontendComponentName: String { "ha-state-control-cover-buttons" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
