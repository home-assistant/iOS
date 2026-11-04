#if !os(watchOS)
import SwiftUI

/// A segmented control sized to sit in a tile beside a slider — one filled option among several on a
/// quiet track. The SwiftUI counterpart of the frontend's `ha-control-select`.
///
/// The sibling of ``HAButtonToggleGroup``, which is the settings-screen form: outlined, text-first,
/// and sized to its content. This one is a control-sized block that fills its space.
public struct HAControlSelect: View {
    private let options: [HAControlSelectOption]
    private let vertical: Bool
    private let hidesOptionLabels: Bool
    private let isDisabled: Bool
    private let tint: Color
    private let trackColor: Color
    private let thickness: CGFloat
    private let cornerRadius: CGFloat
    private let iconSize: CGFloat
    @Binding private var selection: String?

    /// - Parameter hidesOptionLabels: Shows only the icons, for a row too tight for words. Options
    ///   without an icon still show their label, so nothing becomes unreadable.
    public init(
        options: [HAControlSelectOption],
        selection: Binding<String?>,
        vertical: Bool = false,
        hidesOptionLabels: Bool = false,
        isDisabled: Bool = false,
        tint: Color = .haPrimary,
        trackColor: Color = .haDisabled,
        thickness: CGFloat = 40,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.oneAndMicro,
        iconSize: CGFloat = 20
    ) {
        self.options = options
        _selection = selection
        self.vertical = vertical
        self.hidesOptionLabels = hidesOptionLabels
        self.isDisabled = isDisabled
        self.tint = tint
        self.trackColor = trackColor
        self.thickness = thickness
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
    }

    private static let padding = DesignSystem.Spaces.half

    private var layout: AnyLayout {
        vertical
            ? AnyLayout(VStackLayout(spacing: Self.padding))
            : AnyLayout(HStackLayout(spacing: Self.padding))
    }

    public var body: some View {
        layout {
            ForEach(options) { option in
                let isSelected = selection == option.id
                Button {
                    selection = option.id
                } label: {
                    VStack(spacing: DesignSystem.Spaces.micro) {
                        if let icon = option.icon {
                            MaterialDesignIconsImage(icon: icon, size: iconSize)
                        }
                        if !hidesOptionLabels || option.icon == nil {
                            Text(option.label)
                                .font(.system(size: 12))
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white : Color(uiColor: .label))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isSelected ? tint : .clear)
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius - Self.padding)
                    )
                }
                .buttonStyle(.plain)
                .disabled(option.isDisabled)
                .opacity(option.isDisabled ? 0.5 : 1)
                .accessibilityLabel(Text(option.label))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Self.padding)
        .frame(
            width: vertical ? thickness : nil,
            height: vertical ? nil : thickness
        )
        .background(trackColor.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAControlSelect(
            options: [
                .init(id: "off", label: "Off"),
                .init(id: "heat", label: "Heat"),
                .init(id: "cool", label: "Cool"),
            ],
            selection: .constant("heat")
        )
        HAControlSelect(
            options: [
                .init(id: "off", label: "Off", icon: .powerIcon),
                .init(id: "heat", label: "Heat", icon: .fireIcon),
                .init(id: "cool", label: "Cool", icon: .snowflakeIcon),
            ],
            selection: .constant("cool"),
            hidesOptionLabels: true
        )
        HAControlSelect(
            options: [.init(id: "a", label: "A"), .init(id: "b", label: "B", isDisabled: true)],
            selection: .constant("a")
        )
    }
    .padding()
}

extension HAControlSelect: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-select" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
