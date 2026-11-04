#if !os(watchOS)
import HAIconic
import SFSafeSymbols
import SwiftUI

/// A chip standing for something the user entered or picked, with a control to take it back out.
/// The SwiftUI counterpart of the frontend's `ha-input-chip`.
public struct HAInputChip: View {
    private let label: String
    private let icon: MaterialDesignIcons?
    private let isSelected: Bool
    private let onRemove: (() -> Void)?
    private let action: (() -> Void)?

    /// - Parameters:
    ///   - onRemove: Adds the trailing remove control. Without it the chip is just a token; the
    ///     frontend leaves removing to the caller too.
    public init(
        _ label: String,
        icon: MaterialDesignIcons? = nil,
        isSelected: Bool = false,
        action: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            // The chip's own action is a Button around its label, not a gesture on the container
            // that also owns the remove button: as a gesture the two compete, and assistive
            // technology gets no named control for the primary action at all.
            Button {
                action?()
            } label: {
                HStack(spacing: DesignSystem.Spaces.one) {
                    if let icon {
                        MaterialDesignIconsImage(icon: icon, size: 18)
                    }
                    Text(label)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(action == nil)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemSymbol: .xmark)
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.removeChip))
            }
        }
        .haChipShape(
            cornerRadius: DesignSystem.CornerRadius.two,
            background: isSelected ? Color(uiColor: .label).opacity(0.15) : .clear,
            showsOutline: !isSelected
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAInputChip("Plain")
        HAInputChip("Removable", onRemove: {})
        HAInputChip("With icon", icon: .homeOutlineIcon, onRemove: {})
        HAInputChip("Selected", icon: .homeOutlineIcon, isSelected: true, onRemove: {})
    }
    .padding()
}

extension HAInputChip: FrontendComponent {
    public static var frontendComponentName: String { "ha-input-chip" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
