#if !os(watchOS)
import HAIconic
import SwiftUI

/// A quietly-filled button naming a setting and its value, opening a menu of the choices. The
/// SwiftUI counterpart of the frontend's `ha-control-select-menu`.
///
/// The menu is the platform's: a `Picker` inside a `Menu`, so the selected choice carries the
/// system checkmark.
public struct HAControlSelectMenu: View {
    private let label: String
    private let icon: MaterialDesignIcons?
    private let options: [HAControlSelectOption]
    private let hidesLabel: Bool
    private let showsArrow: Bool
    private let isDisabled: Bool
    @Binding private var selection: String?

    /// - Parameters:
    ///   - icon: Shown when the selected option has no icon of its own.
    ///   - showsArrow: Adds the drop-down caret on the trailing edge, the frontend's `show-arrow`.
    public init(
        label: String,
        icon: MaterialDesignIcons? = nil,
        options: [HAControlSelectOption],
        selection: Binding<String?>,
        hidesLabel: Bool = false,
        showsArrow: Bool = false,
        isDisabled: Bool = false
    ) {
        self.label = label
        self.icon = icon
        self.options = options
        _selection = selection
        self.hidesLabel = hidesLabel
        self.showsArrow = showsArrow
        self.isDisabled = isDisabled
    }

    /// The same menu from a more-info dialog's model of it.
    public init(_ select: HAMoreInfoSelect) {
        self.init(
            label: select.label,
            icon: select.icon,
            options: select.options,
            selection: select.selection,
            isDisabled: select.isDisabled
        )
    }

    private var selected: HAControlSelectOption? {
        options.first { $0.id == selection }
    }

    public var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options) { option in
                    Group {
                        if let icon = option.icon {
                            Label {
                                Text(option.label)
                            } icon: {
                                MaterialDesignIconsImage.templateImage(icon: icon, size: 20)
                            }
                        } else {
                            Text(option.label)
                        }
                    }
                    .tag(Optional(option.id))
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spaces.oneAndMicro) {
                if let icon = selected?.icon ?? icon {
                    MaterialDesignIconsImage(icon: icon, size: 20)
                }
                VStack(alignment: .leading, spacing: .zero) {
                    if !hidesLabel {
                        Text(label)
                            .font(.system(size: selected == nil ? 14 : 12))
                    }
                    if let selected {
                        Text(selected.label)
                            .font(.system(size: 14))
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                if showsArrow {
                    MaterialDesignIconsImage(icon: .menuDownIcon, size: 20)
                }
            }
            .foregroundStyle(isDisabled ? Color.secondary : Color(uiColor: .label))
            .padding(.vertical, DesignSystem.Spaces.half)
            .padding(.horizontal, DesignSystem.Spaces.oneAndMicro)
            .frame(height: 48)
            .background(Color.haDisabled.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(selected?.label ?? ""))
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAControlSelectMenu(
            label: "Mode",
            icon: .thermostatIcon,
            options: [
                .init(id: "heat", label: "Heat", icon: .fireIcon),
                .init(id: "cool", label: "Cool", icon: .snowflakeIcon),
            ],
            selection: .constant("heat")
        )
        HAControlSelectMenu(
            label: "Fan mode",
            icon: .fanIcon,
            options: [.init(id: "low", label: "Low"), .init(id: "high", label: "High")],
            selection: .constant("low"),
            showsArrow: true
        )
        HAControlSelectMenu(
            label: "Preset",
            icon: .tuneVariantIcon,
            options: [.init(id: "eco", label: "Eco")],
            selection: .constant(nil),
            isDisabled: true
        )
    }
    .frame(width: 160)
    .padding()
}

extension HAControlSelectMenu: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-select-menu" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
