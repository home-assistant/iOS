#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// A chip that narrows a list, toggling between selected and not. The SwiftUI counterpart of the
/// frontend's `ha-filter-chip`.
///
/// Selecting one fills it and puts a check ahead of the label — the check is what distinguishes a
/// filter chip from an assist chip, so it is on unless `showsLeadingCheck` turns it off for a row
/// tight enough that the fill alone has to carry the state.
public struct HAFilterChip: View {
    private let label: String
    private let isSelected: Bool
    private let showsLeadingCheck: Bool
    private let action: () -> Void

    public init(
        _ label: String,
        isSelected: Bool,
        showsLeadingCheck: Bool = true,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.showsLeadingCheck = showsLeadingCheck
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spaces.one) {
                if isSelected, showsLeadingCheck {
                    Image(systemSymbol: .checkmark)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(label)
            }
            .haChipShape(
                // `--md-filter-chip-container-shape: var(--ha-border-radius-md)`, squarer than the
                // assist and input chips.
                cornerRadius: DesignSystem.CornerRadius.one,
                background: isSelected ? Color(uiColor: .label).opacity(0.15) : .clear,
                showsOutline: !isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAFilterChip("Unselected", isSelected: false) {}
        HAFilterChip("Selected", isSelected: true) {}
        HAFilterChip("Selected, no check", isSelected: true, showsLeadingCheck: false) {}
    }
    .padding()
}

extension HAFilterChip: FrontendComponent {
    public static var frontendComponentName: String { "ha-filter-chip" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
