#if !os(watchOS)
import HAIconic
import SwiftUI

/// The dashboard's chunky switch: a half-width block that slides across a tinted track. The SwiftUI
/// counterpart of the frontend's `ha-control-switch`.
///
/// Unlike the platform toggle, this fills the space it is given — it is sized to sit in a tile
/// beside a slider, not at the end of a settings row. For the latter, use SwiftUI's `Toggle`.
public struct HAControlSwitch: View {
    private let vertical: Bool
    private let reversed: Bool
    private let iconOn: MaterialDesignIcons?
    private let iconOff: MaterialDesignIcons?
    private let isDisabled: Bool
    private let label: String?
    @Binding private var isOn: Bool

    /// - Parameter reversed: Starts the block at the far end, so switching on moves it towards the
    ///   leading edge instead of away from it.
    public init(
        isOn: Binding<Bool>,
        vertical: Bool = false,
        reversed: Bool = false,
        iconOn: MaterialDesignIcons? = nil,
        iconOff: MaterialDesignIcons? = nil,
        isDisabled: Bool = false,
        label: String? = nil
    ) {
        _isOn = isOn
        self.vertical = vertical
        self.reversed = reversed
        self.iconOn = iconOn
        self.iconOff = iconOff
        self.isDisabled = isDisabled
        self.label = label
    }

    private static let thickness: CGFloat = 40
    private static let padding = DesignSystem.Spaces.half

    /// On tints with the brand colour, off with the disabled grey — the block and the track behind
    /// it share the colour, the track at 20%.
    private var tint: Color {
        isOn ? .haPrimary : .haDisabled
    }

    /// Switching on moves the block to the far end; `reversed` swaps which end that is.
    private var isAtFarEnd: Bool {
        isOn != reversed
    }

    private var layout: AnyLayout {
        vertical
            ? AnyLayout(VStackLayout(spacing: .zero))
            : AnyLayout(HStackLayout(spacing: .zero))
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf)
                .fill(tint.opacity(0.2))
            // The block is half the track, as `.switch .button { width: 50% }` is — not a thumb.
            // An equally weighted spacer on one side is what splits it, so no measurement is needed.
            layout {
                if isAtFarEnd {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf - Self.padding)
                    .fill(tint)
                    .overlay {
                        if let icon = isOn ? iconOn : iconOff {
                            MaterialDesignIconsImage(icon: icon, size: 20)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if !isAtFarEnd {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(Self.padding)
        }
        .frame(
            width: vertical ? Self.thickness : nil,
            height: vertical ? nil : Self.thickness
        )
        .opacity(isDisabled ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            withAnimation(DesignSystem.Animation.easeInOutFaster) { isOn.toggle() }
        }
        .accessibilityElement()
        .accessibilityLabel(optional: label)
        // `.isToggle` is iOS 17; the package targets 16, and a button trait plus an on/off value
        // reads the same way to VoiceOver on both.
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(isOn ? "1" : "0"))
    }
}

#Preview("Horizontal") {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAControlSwitch(isOn: .constant(true), label: "On")
        HAControlSwitch(isOn: .constant(false), label: "Off")
        HAControlSwitch(
            isOn: .constant(true),
            iconOn: .lightbulbOnIcon,
            iconOff: .lightbulbOutlineIcon,
            label: "With icons"
        )
        HAControlSwitch(isOn: .constant(true), reversed: true, label: "Reversed")
        HAControlSwitch(isOn: .constant(true), isDisabled: true, label: "Disabled")
    }
    .padding()
}

#Preview("Vertical") {
    HStack(spacing: DesignSystem.Spaces.three) {
        HAControlSwitch(isOn: .constant(true), vertical: true, label: "On")
        HAControlSwitch(isOn: .constant(false), vertical: true, label: "Off")
    }
    .frame(height: 160)
    .padding()
}

extension HAControlSwitch: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-switch" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
