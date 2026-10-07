#if !os(watchOS)
import SwiftUI

/// A row of buttons of which exactly one is active — a segmented control. The SwiftUI counterpart of
/// the frontend's `ha-button-toggle-group`.
///
/// The selection is the caller's: this reports taps and draws whichever button matches `selection`,
/// rather than owning the state, so it can be driven from a binding the rest of a screen shares.
public struct HAButtonToggleGroup: View {
    private let buttons: [HAToggleButton]
    private let fullWidth: Bool
    private let isDisabled: Bool
    @Binding private var selection: String?

    /// - Parameter fullWidth: Stretches the buttons to share the available width equally, the
    ///   frontend's `full-width`. Otherwise each is as wide as its content.
    public init(
        buttons: [HAToggleButton],
        selection: Binding<String?>,
        fullWidth: Bool = false,
        isDisabled: Bool = false
    ) {
        self.buttons = buttons
        _selection = selection
        self.fullWidth = fullWidth
        self.isDisabled = isDisabled
    }

    public var body: some View {
        HStack(spacing: .zero) {
            ForEach(buttons) { button in
                let isActive = selection == button.id
                Button {
                    selection = button.id
                } label: {
                    Group {
                        if let icon = button.icon {
                            MaterialDesignIconsImage(icon: icon, size: 20)
                        } else {
                            Text(button.label)
                                .font(.system(size: 14))
                                // A segment is a quarter of the bar at most; a label that wraps
                                // makes the row two lines tall and misaligns it with its siblings,
                                // so it shrinks to fit instead.
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: fullWidth ? .infinity : nil)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                    .frame(height: 40)
                    .foregroundStyle(isActive ? Color.white : Color(uiColor: .label))
                    .background(isActive ? Color.haPrimary : .clear)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(button.label))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one)
                .strokeBorder(Color.haDivider, lineWidth: DesignSystem.Border.Width.default)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAButtonToggleGroup(
            buttons: [
                .init(id: "day", label: "Day"),
                .init(id: "week", label: "Week"),
                .init(id: "month", label: "Month"),
            ],
            selection: .constant("week")
        )
        HAButtonToggleGroup(
            buttons: [
                .init(id: "list", label: "List", icon: .formatListBulletedIcon),
                .init(id: "grid", label: "Grid", icon: .viewGridIcon),
            ],
            selection: .constant("grid")
        )
        HAButtonToggleGroup(
            buttons: [.init(id: "a", label: "A"), .init(id: "b", label: "B")],
            selection: .constant("a"),
            fullWidth: true
        )
    }
    .padding()
}

extension HAButtonToggleGroup: FrontendComponent {
    public static var frontendComponentName: String { "ha-button-toggle-group" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
