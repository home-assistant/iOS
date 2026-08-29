#if !os(watchOS)
import HAIconic
import SwiftUI

/// A value with a minus and a plus either side of it, for setting a number without dragging. The
/// SwiftUI counterpart of the frontend's `ha-control-number-buttons`.
///
/// Shares ``HASliderScale`` with ``HAControlSlider``: the frontend applies the same clamp-after-snap
/// rule in both, and keeping one implementation means one place for it to be right.
public struct HAControlNumberButtons: View {
    @Environment(\.locale) private var locale
    private let scale: HASliderScale
    private let unit: String?
    private let fractionLength: Int
    private let isDisabled: Bool
    private let label: String?
    @Binding private var value: Double

    public init(
        value: Binding<Double>,
        scale: HASliderScale = HASliderScale(),
        unit: String? = nil,
        fractionLength: Int = 0,
        isDisabled: Bool = false,
        label: String? = nil
    ) {
        _value = value
        self.scale = scale
        self.unit = unit
        self.fractionLength = fractionLength
        self.isDisabled = isDisabled
        self.label = label
    }

    private var formattedValue: String {
        let number = scale.stepped(value)
            .formatted(.number.precision(.fractionLength(fractionLength)).locale(locale))
        return unit.map { "\(number) \($0)" } ?? number
    }

    public var body: some View {
        HStack(spacing: .zero) {
            button(icon: .minusIcon, label: "−", isEnabled: scale.stepped(value) > scale.min) {
                value = scale.stepped(value - scale.step)
            }
            Text(formattedValue)
                .font(DesignSystem.Font.body)
                .frame(maxWidth: .infinity)
            button(icon: .plusIcon, label: "+", isEnabled: scale.stepped(value) < scale.max) {
                value = scale.stepped(value + scale.step)
            }
        }
        .frame(height: 40)
        .background(Color.haDisabled.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndMicro))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(optional: label)
    }

    private func button(
        icon: MaterialDesignIcons,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MaterialDesignIconsImage(icon: icon, size: 20)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        // At a bound the step would do nothing, so the button says so rather than going dead.
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAControlNumberButtons(
            value: .constant(21),
            scale: HASliderScale(min: 7, max: 35, step: 0.5),
            unit: "°C",
            fractionLength: 1
        )
        HAControlNumberButtons(value: .constant(50))
        HAControlNumberButtons(value: .constant(0), label: "At minimum")
        HAControlNumberButtons(value: .constant(50), isDisabled: true)
    }
    .padding()
}

extension HAControlNumberButtons: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-number-buttons" }
}

#endif
