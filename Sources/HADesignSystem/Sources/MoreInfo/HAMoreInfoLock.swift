#if !os(watchOS)
import HAIconic
import SwiftUI

/// A lock's more-info dialog: a tall switch between locked and unlocked, a two-tap "Open door"
/// button for locks that can open, and lock/unlock buttons when it reports itself jammed. The
/// SwiftUI counterpart of the frontend's `more-info-lock`, with `ha-state-control-lock-toggle`.
public struct HAMoreInfoLock: View {
    private enum OpenStep {
        case ready
        case confirming
        case done
    }

    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let color: Color
    private let lockedIcon: MaterialDesignIcons
    private let unlockedIcon: MaterialDesignIcons
    private let jammedIcon: MaterialDesignIcons
    private let isUnknown: Bool
    private let isJammed: Bool
    private let isUnavailable: Bool
    private let canOpen: Bool
    private let onOpen: (() -> Void)?
    @Binding private var isLocked: Bool
    @State private var openStep: OpenStep = .ready

    /// - Parameters:
    ///   - color: The state's colour; the switch uses it for both positions, as the frontend does.
    ///   - lockedIcon: The state icon for locked, or locking while that is under way.
    ///   - isUnknown: Shows lock and unlock buttons instead of a switch claiming a position.
    ///   - isJammed: Shows the jammed icon in place of the switch, with lock and unlock buttons under.
    ///   - onOpen: Adds the open button, for a lock that supports `OPEN`. The first tap asks to be
    ///     sure; the second calls this.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        isLocked: Binding<Bool>,
        color: Color,
        lockedIcon: MaterialDesignIcons = .lockIcon,
        unlockedIcon: MaterialDesignIcons = .lockOpenVariantIcon,
        jammedIcon: MaterialDesignIcons = .lockAlertIcon,
        isUnknown: Bool = false,
        isJammed: Bool = false,
        isUnavailable: Bool = false,
        canOpen: Bool = true,
        onOpen: (() -> Void)? = nil
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        _isLocked = isLocked
        self.color = color
        self.lockedIcon = lockedIcon
        self.unlockedIcon = unlockedIcon
        self.jammedIcon = jammedIcon
        self.isUnknown = isUnknown
        self.isJammed = isJammed
        self.isUnavailable = isUnavailable
        self.canOpen = canOpen
        self.onOpen = onOpen
    }

    private var strings: HADesignSystemEnvironment.Strings { HADesignSystemEnvironment.current.strings }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: state, lastChanged: lastChanged, now: now)
        } controls: {
            if isJammed {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.StateControl.cornerRadius)
                        .fill(color.opacity(0.2))
                    MaterialDesignIconsImage(icon: jammedIcon, size: 48)
                        .foregroundStyle(color)
                }
                .frame(width: DesignSystem.StateControl.thickness, height: DesignSystem.StateControl.length)
            } else {
                HAStateControlToggle(
                    isOn: $isLocked,
                    onColor: color,
                    offColor: color,
                    iconOn: lockedIcon,
                    iconOff: unlockedIcon,
                    onLabel: strings.lock,
                    offLabel: strings.unlock,
                    isAssumedState: isUnknown,
                    isDisabled: isUnavailable
                )
            }
            if let onOpen {
                Group {
                    if openStep == .done {
                        Label {
                            Text(strings.openDoorDone)
                        } icon: {
                            MaterialDesignIconsImage(icon: .checkIcon, size: 20)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.haSuccessColor)
                    } else {
                        HAControlButton(
                            title: openStep == .confirming ? strings.openDoorConfirm : strings.openDoor,
                            isDisabled: !canOpen || isUnavailable,
                            cornerRadius: DesignSystem.CornerRadius.oneAndHalf,
                            activeColor: openStep == .confirming ? .haErrorColor : nil
                        ) {
                            if openStep == .confirming {
                                onOpen()
                                openStep = .done
                            } else {
                                openStep = .confirming
                            }
                        }
                        .frame(width: DesignSystem.StateControl.thickness, height: 40)
                    }
                }
                .task(id: openStep) {
                    guard openStep != .ready else { return }
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    openStep = .ready
                }
            }
        } footer: {
            if isJammed {
                HAControlButtonGroup(spacing: DesignSystem.Spaces.oneAndHalf) {
                    HAControlButton(title: strings.unlock) { isLocked = false }
                    HAControlButton(title: strings.lock) { isLocked = true }
                }
                .frame(maxWidth: DesignSystem.StateControl.length)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.four) {
            HAMoreInfoLock(
                state: "Locked",
                lastChanged: Date(timeIntervalSinceNow: -420),
                now: Date(),
                isLocked: .constant(true),
                color: FrontendColors.stateLockLockedColor.color,
                onOpen: {}
            )
            HAMoreInfoLock(
                state: "Jammed",
                lastChanged: Date(timeIntervalSinceNow: -60),
                now: Date(),
                isLocked: .constant(false),
                color: FrontendColors.stateLockJammedColor.color,
                isJammed: true
            )
        }
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoLock: FrontendComponent {
    public static var frontendComponentName: String { "more-info-lock" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
