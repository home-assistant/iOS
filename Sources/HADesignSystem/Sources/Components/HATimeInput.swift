#if !os(watchOS)
import SwiftUI

/// A time of day, entered as hours and minutes with optional seconds. The SwiftUI counterpart of
/// the frontend's `ha-time-input`.
///
/// Thin by design: it picks the clock and bounds, and ``HABaseTimeInput`` draws the boxes — the
/// same split the frontend makes.
public struct HATimeInput: View {
    @Environment(\.locale) private var locale

    @Binding private var value: HATimeComponents
    private let label: String?
    private let helper: String?
    private let required: Bool
    private let disabled: Bool
    private let enableSecond: Bool
    private let clearable: Bool
    private let format: HABaseTimeInput.Format?
    private let onClear: (() -> Void)?

    /// - Parameter format: Left `nil`, the clock follows the locale, as `useAmPm(locale)` does in
    ///   the frontend. Pass one to force it — a snapshot test wants to see both.
    public init(
        value: Binding<HATimeComponents>,
        label: String? = nil,
        helper: String? = nil,
        required: Bool = false,
        disabled: Bool = false,
        enableSecond: Bool = false,
        clearable: Bool = false,
        format: HABaseTimeInput.Format? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self._value = value
        self.label = label
        self.helper = helper
        self.required = required
        self.disabled = disabled
        self.enableSecond = enableSecond
        self.clearable = clearable
        self.format = format
        self.onClear = onClear
    }

    /// Whether the locale writes times with AM/PM. Asking `DateFormatter` for the "j" skeleton —
    /// the hour field in whichever convention the locale uses — is the standard way to find out:
    /// a 12-hour locale puts an "a" in the pattern it hands back.
    private var resolvedFormat: HABaseTimeInput.Format {
        if let format {
            return format
        }
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
        return pattern.contains("a") ? .twelve : .twentyFour
    }

    public var body: some View {
        HABaseTimeInput(
            value: $value,
            label: label,
            helper: helper,
            required: required,
            disabled: disabled,
            format: resolvedFormat,
            enableSecond: enableSecond,
            clearable: clearable,
            onClear: onClear
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
        HATimeInput(value: .constant(HATimeComponents(hours: 8, minutes: 5)), label: "Wake up")
        HATimeInput(
            value: .constant(HATimeComponents(hours: 22, minutes: 45, seconds: 30)),
            label: "With seconds",
            enableSecond: true,
            format: .twentyFour
        )
        HATimeInput(
            value: .constant(HATimeComponents(hours: 7, minutes: 15, period: .pm)),
            label: "12-hour",
            format: .twelve
        )
    }
    .padding()
}

extension HATimeInput: FrontendComponent {
    public static var frontendComponentName: String { "ha-time-input" }
}

#endif
