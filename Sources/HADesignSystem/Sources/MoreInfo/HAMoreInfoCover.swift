#if !os(watchOS)
import HAIconic
import SwiftUI

/// A cover's more-info dialog: its position and tilt sliders, or its open/stop/close buttons, with a
/// switch between the two when it has both. The SwiftUI counterpart of the frontend's
/// `more-info-cover`.
public struct HAMoreInfoCover: View {
    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let color: Color
    private let position: Binding<Double>?
    private let tiltPosition: Binding<Double>?
    private let buttons: HAStateControlCoverButtons?
    private let toggle: Binding<Bool>?
    private let isUnavailable: Bool
    @State private var showsButtons = false

    /// - Parameters:
    ///   - state: The header, "Open · 50%".
    ///   - position: 0 closed to 100 open, when the cover reports where it is.
    ///   - tiltPosition: The same for the slats, when it tilts.
    ///   - buttons: The cover's commands, when it has any.
    ///   - toggle: Open (`true`) or closed, for a cover that only opens and closes; it then shows a
    ///     switch instead of buttons.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        color: Color,
        position: Binding<Double>? = nil,
        tiltPosition: Binding<Double>? = nil,
        buttons: HAStateControlCoverButtons? = nil,
        toggle: Binding<Bool>? = nil,
        isUnavailable: Bool = false
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        self.color = color
        self.position = position
        self.tiltPosition = tiltPosition
        self.buttons = buttons
        self.toggle = toggle
        self.isUnavailable = isUnavailable
    }

    private var hasSliders: Bool { position != nil || tiltPosition != nil }
    private var hasButtons: Bool { buttons != nil || toggle != nil }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: state, lastChanged: lastChanged, now: now)
        } controls: {
            HStack(spacing: DesignSystem.Spaces.three) {
                if hasSliders, !(showsButtons && hasButtons) {
                    if let position {
                        HAStateControlSlider(value: position, mode: .end, color: color, isDisabled: isUnavailable)
                    }
                    if let tiltPosition {
                        HAStateControlSlider(
                            value: tiltPosition,
                            mode: .cursor,
                            track: .slats,
                            color: color,
                            showsHandle: false,
                            isDisabled: isUnavailable
                        )
                    }
                } else if let toggle {
                    HAStateControlToggle(
                        isOn: toggle,
                        onColor: color,
                        offColor: color,
                        iconOn: .windowShutterOpenIcon,
                        iconOff: .windowShutterIcon,
                        isDisabled: isUnavailable
                    )
                } else if let buttons {
                    buttons
                }
            }
            if hasSliders, hasButtons {
                HAIconButtonGroup {
                    HAIconButtonToggle(
                        icon: .menuIcon,
                        label: HADesignSystemEnvironment.current.strings.coverPositionMode,
                        isSelected: Binding(get: { !showsButtons }, set: { _ in showsButtons = false })
                    )
                    HAIconButtonToggle(
                        icon: .swapVerticalIcon,
                        label: HADesignSystemEnvironment.current.strings.coverButtonsMode,
                        isSelected: Binding(get: { showsButtons }, set: { _ in showsButtons = true })
                    )
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.four) {
            HAMoreInfoCover(
                state: "Open · 50%",
                lastChanged: Date(timeIntervalSinceNow: -3060),
                now: Date(),
                color: FrontendColors.stateCoverActiveColor.color,
                position: .constant(50),
                tiltPosition: .constant(30),
                buttons: HAStateControlCoverButtons(
                    open: HAMoreInfoCommand(id: "open", icon: .arrowUpIcon, label: "Open") {},
                    stop: HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {},
                    close: HAMoreInfoCommand(id: "close", icon: .arrowDownIcon, label: "Close") {}
                )
            )
            HAMoreInfoCover(
                state: "Open",
                lastChanged: Date(timeIntervalSinceNow: -300),
                now: Date(),
                color: FrontendColors.stateCoverActiveColor.color,
                buttons: HAStateControlCoverButtons(
                    open: HAMoreInfoCommand(id: "open", icon: .arrowUpIcon, label: "Open") {},
                    stop: HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {},
                    close: HAMoreInfoCommand(id: "close", icon: .arrowDownIcon, label: "Close") {}
                )
            )
        }
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoCover: FrontendComponent {
    public static var frontendComponentName: String { "more-info-cover" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
