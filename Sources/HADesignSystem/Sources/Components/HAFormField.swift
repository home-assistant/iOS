#if !os(watchOS)
import SwiftUI

/// A control with its label beside it, and optional helper text underneath. Covers the frontend's
/// `ha-formfield` and `ha-input-helper-text`, which are always used together.
///
/// Layout only: it places the label beside the control and the helper text beneath, and does not
/// forward taps on the label to the control. Widening the hit target that way needs the control's
/// own binding, which this does not have — a caller wanting it should put the label inside a
/// `Toggle` rather than beside one.
public struct HAFormField<Control: View>: View {
    private let label: String
    private let helperText: String?
    private let isError: Bool
    private let controlLeading: Bool
    private let control: Control

    /// - Parameters:
    ///   - isError: Colours the helper text as a validation failure.
    ///   - controlLeading: Puts the control before the label, as a checkbox row does; trailing is
    ///     the settings-row arrangement.
    public init(
        label: String,
        helperText: String? = nil,
        isError: Bool = false,
        controlLeading: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.label = label
        self.helperText = helperText
        self.isError = isError
        self.controlLeading = controlLeading
        self.control = control()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            HStack(spacing: DesignSystem.Spaces.one) {
                // The label wraps rather than truncating: a form field's label is the question
                // being asked, and half of one is no use.
                if controlLeading {
                    control
                    Text(label)
                        .font(DesignSystem.Font.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: .zero)
                } else {
                    Text(label)
                        .font(DesignSystem.Font.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DesignSystem.Spaces.one)
                    control
                }
            }
            if let helperText {
                Text(helperText)
                    .font(.system(size: 12))
                    .foregroundStyle(isError ? Color.haErrorColor : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAFormField(label: "Enable notifications") {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        HAFormField(label: "Track location", helperText: "Used for zone automations.") {
            Toggle("", isOn: .constant(false)).labelsHidden()
        }
        HAFormField(label: "Server address", helperText: "Not a valid URL.", isError: true) {
            Toggle("", isOn: .constant(false)).labelsHidden()
        }
        HAFormField(label: "Trailing control", controlLeading: false) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
    }
    .padding()
}

extension HAFormField: FrontendComponent {
    public static var frontendComponentName: String { "ha-formfield" }
}

#endif
