#if !os(watchOS)
import SwiftUI

/// A span of time — "wait 5 minutes", "for 1 day 2 hours". The SwiftUI counterpart of the
/// frontend's `ha-duration-input`.
///
/// Unlike ``HATimeInput`` the hours box has no ceiling: a duration of 40 hours is a sensible
/// answer where a time of day is not. Overflow in any box carries into the next through
/// ``HATimeComponents/normalized(enableDay:enableSecond:negative:)``, so typing 90 into minutes
/// settles as 1 hour 30 minutes.
public struct HADurationInput: View {
    private static let plusID = "+"
    private static let minusID = "-"

    @Binding private var value: HATimeComponents
    @Binding private var isNegative: Bool
    private let label: String?
    private let helper: String?
    private let required: Bool
    private let disabled: Bool
    private let enableDay: Bool
    private let enableSecond: Bool
    private let enableMillisecond: Bool
    private let allowNegative: Bool
    private let clearable: Bool
    private let onClear: (() -> Void)?

    /// - Parameters:
    ///   - isNegative: The sign, kept apart from the magnitudes because that is how the frontend
    ///     stores it — the boxes always show positive numbers and the toggle carries the sign.
    ///     Ignored unless `allowNegative` is set.
    ///   - allowNegative: Shows the `+`/`-` toggle ahead of the boxes.
    public init(
        value: Binding<HATimeComponents>,
        isNegative: Binding<Bool> = .constant(false),
        label: String? = nil,
        helper: String? = nil,
        required: Bool = false,
        disabled: Bool = false,
        enableDay: Bool = false,
        enableSecond: Bool = true,
        enableMillisecond: Bool = false,
        allowNegative: Bool = false,
        clearable: Bool = false,
        onClear: (() -> Void)? = nil
    ) {
        self._value = value
        self._isNegative = isNegative
        self.label = label
        self.helper = helper
        self.required = required
        self.disabled = disabled
        self.enableDay = enableDay
        self.enableSecond = enableSecond
        self.enableMillisecond = enableMillisecond
        self.allowNegative = allowNegative
        self.clearable = clearable
        self.onClear = onClear
    }

    private var signSelection: Binding<String?> {
        Binding(
            get: { isNegative ? Self.minusID : Self.plusID },
            set: { isNegative = $0 == Self.minusID }
        )
    }

    /// Carries overflow between boxes on every edit, which is where the frontend does it too —
    /// `_durationChanged` normalises the event before it leaves the element, so the value a parent
    /// sees is always settled.
    private var normalizing: Binding<HATimeComponents> {
        Binding(
            get: { value },
            set: { value = $0.normalized(enableDay: enableDay, enableSecond: enableSecond) }
        )
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spaces.two) {
            if allowNegative {
                HAButtonToggleGroup(
                    buttons: [
                        HAToggleButton(id: Self.plusID, label: "+", icon: .plusThickIcon),
                        HAToggleButton(id: Self.minusID, label: "-", icon: .minusThickIcon),
                    ],
                    selection: signSelection,
                    isDisabled: disabled
                )
            }
            HABaseTimeInput(
                value: normalizing,
                label: label,
                helper: helper,
                required: required,
                disabled: disabled,
                format: .twentyFour,
                enableDay: enableDay,
                enableSecond: enableSecond,
                enableMillisecond: enableMillisecond,
                noHoursLimit: true,
                clearable: clearable,
                onClear: onClear
            )
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
        HADurationInput(value: .constant(HATimeComponents(minutes: 5)), label: "Wait")
        HADurationInput(
            value: .constant(HATimeComponents(days: 1, hours: 2, minutes: 30, seconds: 15)),
            label: "With days",
            enableDay: true
        )
        HADurationInput(
            value: .constant(HATimeComponents(hours: 0, minutes: 30)),
            isNegative: .constant(true),
            label: "Offset",
            allowNegative: true
        )
    }
    .padding()
}

extension HADurationInput: FrontendComponent {
    public static var frontendComponentName: String { "ha-duration-input" }
}

#endif
