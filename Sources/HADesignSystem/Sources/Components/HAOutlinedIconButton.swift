#if !os(watchOS)
import HAIconic
import SwiftUI

/// A round icon button drawn as an outline: the minus and plus under a thermostat dial, the fan's
/// power button. The SwiftUI counterpart of the frontend's `ha-outlined-icon-button`.
public struct HAOutlinedIconButton: View {
    private let icon: MaterialDesignIcons
    private let label: String
    private let outlineColor: Color?
    private let isDisabled: Bool
    private let action: () -> Void

    /// - Parameter outlineColor: Tints the ring, as a dual thermostat does with the target the
    ///   buttons move. Defaults to the divider grey.
    public init(
        icon: MaterialDesignIcons,
        label: String,
        outlineColor: Color? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.outlineColor = outlineColor
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MaterialDesignIconsImage(icon: icon, size: 24)
                .foregroundStyle(isDisabled ? Color.secondary : Color(uiColor: .label))
                .frame(width: 48, height: 48)
                .overlay(Circle().strokeBorder(outlineColor ?? Color.haDivider, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.three) {
        HAOutlinedIconButton(icon: .minusIcon, label: "Decrease") {}
        HAOutlinedIconButton(icon: .plusIcon, label: "Increase", outlineColor: .orange) {}
        HAOutlinedIconButton(icon: .powerIcon, label: "Power", isDisabled: true) {}
    }
    .padding()
}

extension HAOutlinedIconButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-outlined-icon-button" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
