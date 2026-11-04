#if !os(watchOS)
import SwiftUI

/// A date, shown as a filled field with a calendar affordance and edited in a calendar sheet. The
/// SwiftUI counterpart of the frontend's `ha-date-input`.
///
/// The field itself is never typed into — the frontend's is read-only too, and opens a dialog. The
/// sheet is a plain graphical `DatePicker`, which is the platform's calendar dialog.
public struct HADateInput: View {
    private static let fieldHeight: CGFloat = 56

    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.calendar) private var calendar

    @Binding private var value: Date?
    @State private var isPickerPresented = false
    private let label: String?
    private let helper: String?
    private let disabled: Bool
    private let required: Bool
    private let canClear: Bool
    private let minimum: Date?
    private let maximum: Date?

    /// - Parameters:
    ///   - canClear: Shows a clear button, the frontend's `can-clear`. Suppressed while the field
    ///     is empty — there is nothing to clear — and while it is required.
    ///   - minimum: Earliest selectable date, the frontend's `min`.
    ///   - maximum: Latest selectable date, the frontend's `max`.
    public init(
        value: Binding<Date?>,
        label: String? = nil,
        helper: String? = nil,
        disabled: Bool = false,
        required: Bool = false,
        canClear: Bool = false,
        minimum: Date? = nil,
        maximum: Date? = nil
    ) {
        self._value = value
        self.label = label
        self.helper = helper
        self.disabled = disabled
        self.required = required
        self.canClear = canClear
        self.minimum = minimum
        self.maximum = maximum
    }

    private var showsClearButton: Bool {
        canClear && !required && !disabled && value != nil
    }

    private var formattedValue: String {
        guard let value else {
            return ""
        }
        return value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            field
            if let helper {
                Text(helper)
                    .font(.system(size: 12))
                    .foregroundStyle(disabled ? Color.haDisabled : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(disabled ? 0.5 : 1)
        .sheet(isPresented: $isPickerPresented) {
            calendarSheet
        }
    }

    /// The clear button is a *sibling* of the button that opens the picker, not a child of its
    /// label. Nested inside it, a tap on Clear would also present the picker, and VoiceOver would
    /// see a button containing another button.
    private var field: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Button {
                isPickerPresented = true
            } label: {
                pickerLabel
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(optional: label)
            .accessibilityValue(Text(formattedValue))
            if showsClearButton {
                Button {
                    value = nil
                } label: {
                    MaterialDesignIconsImage(icon: .closeIcon, size: 18)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.clearValue))
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .frame(height: Self.fieldHeight)
        .frame(maxWidth: .infinity)
        .background(Color.haNeutralQuietFill)
        .clipShape(TopRoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.haDivider)
                .frame(height: DesignSystem.Border.Width.default)
        }
    }

    private var pickerLabel: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            VStack(alignment: .leading, spacing: .zero) {
                if let label {
                    Text(required ? "\(label) *" : label)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text(formattedValue)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(Color.primary)
            }
            Spacer(minLength: DesignSystem.Spaces.one)
            MaterialDesignIconsImage(icon: .calendarIcon, size: 20)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    /// `DatePicker` has no empty state, so an unset field opens on today — the same thing the
    /// frontend's dialog does with no value.
    ///
    /// Today is clamped into the allowed range first: a field that only accepts future dates would
    /// otherwise hand `DatePicker` a selection outside the range it was given.
    private var calendarSheet: some View {
        let selection = Binding(
            get: { (value ?? Date()).clamped(to: dateRange) },
            set: { value = $0 }
        )
        return DatePicker(
            label ?? "",
            selection: selection,
            in: dateRange,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        .environment(\.calendar, calendar)
        .padding()
    }

    private var dateRange: ClosedRange<Date> {
        let lower = minimum ?? Date.distantPast
        let upper = maximum ?? Date.distantFuture
        return lower <= upper ? lower ... upper : lower ... lower
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
        HADateInput(value: .constant(Date(timeIntervalSince1970: 1_787_996_467)), label: "Start date")
        HADateInput(value: .constant(nil), label: "End date", helper: "Leave empty for no end")
        HADateInput(
            value: .constant(Date(timeIntervalSince1970: 1_787_996_467)),
            label: "Clearable",
            canClear: true
        )
    }
    .padding()
}

private extension Date {
    func clamped(to range: ClosedRange<Date>) -> Date {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension HADateInput: FrontendComponent {
    public static var frontendComponentName: String { "ha-date-input" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
