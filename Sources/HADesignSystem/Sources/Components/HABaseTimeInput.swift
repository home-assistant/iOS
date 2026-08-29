#if !os(watchOS)
import SwiftUI

/// A row of colon-separated number boxes for entering a time or a span — days, hours, minutes,
/// seconds, milliseconds, and an AM/PM select on a 12-hour clock. The SwiftUI counterpart of the
/// frontend's `ha-base-time-input`.
///
/// This is the shared machinery, not a control to reach for directly: use ``HATimeInput`` for a
/// time of day and ``HADurationInput`` for a span, exactly as the frontend wraps this element.
///
/// Which boxes appear is the caller's choice, because it is the wrapper's: `ha-duration-input`
/// shows days and seconds for a script delay but hides both for a simple "wait 5 minutes".
public struct HABaseTimeInput: View {
    /// Whether hours run 0–23 or 1–12 beside an AM/PM select.
    public enum Format: Sendable {
        case twelve
        case twentyFour
    }

    /// The row is 56pt tall, matching the frontend's filled fields — the same height as a Material
    /// text field, which is what these boxes are.
    private static let rowHeight: CGFloat = 56
    /// `.time-separator` is a fixed 12px column, narrower than a box so the colon reads as
    /// punctuation between the numbers rather than as another field.
    private static let separatorWidth: CGFloat = 12
    /// `ha-input { width: 60px }`. Fixed rather than flexible: the frontend's wrap is sized to its
    /// content, so the row of boxes is as wide as the boxes and no wider. A `TextField` left to
    /// itself would swallow the whole container instead.
    private static let boxWidth: CGFloat = 60

    @Binding private var value: HATimeComponents
    private let label: String?
    private let helper: String?
    private let required: Bool
    private let disabled: Bool
    private let format: Format
    private let enableDay: Bool
    private let enableSecond: Bool
    private let enableMillisecond: Bool
    private let noHoursLimit: Bool
    private let clearable: Bool
    private let dayLabel: String
    private let hourLabel: String
    private let minuteLabel: String
    private let secondLabel: String
    private let millisecondLabel: String
    private let onClear: (() -> Void)?

    /// - Parameters:
    ///   - noHoursLimit: Lets the hours box exceed a day's worth, which a duration needs and a time
    ///     of day does not.
    ///   - clearable: Shows a clear button at the end of the row. The frontend hides it when the
    ///     field is required or disabled, and so does this.
    public init(
        value: Binding<HATimeComponents>,
        label: String? = nil,
        helper: String? = nil,
        required: Bool = false,
        disabled: Bool = false,
        format: Format = .twentyFour,
        enableDay: Bool = false,
        enableSecond: Bool = false,
        enableMillisecond: Bool = false,
        noHoursLimit: Bool = false,
        clearable: Bool = false,
        dayLabel: String = "dd",
        hourLabel: String = "hh",
        minuteLabel: String = "mm",
        secondLabel: String = "ss",
        millisecondLabel: String = "ms",
        onClear: (() -> Void)? = nil
    ) {
        self._value = value
        self.label = label
        self.helper = helper
        self.required = required
        self.disabled = disabled
        self.format = format
        self.enableDay = enableDay
        self.enableSecond = enableSecond
        self.enableMillisecond = enableMillisecond
        self.noHoursLimit = noHoursLimit
        self.clearable = clearable
        self.dayLabel = dayLabel
        self.hourLabel = hourLabel
        self.minuteLabel = minuteLabel
        self.secondLabel = secondLabel
        self.millisecondLabel = millisecondLabel
        self.onClear = onClear
    }

    /// 23 on a 24-hour clock, 12 on a 12-hour one, and unbounded for a duration — a span of 40
    /// hours is a perfectly good answer where a time of day is not.
    private var hourMax: Int? {
        if noHoursLimit {
            return nil
        }
        return format == .twelve ? 12 : 23
    }

    private var showsClearButton: Bool {
        clearable && !required && !disabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            if let label {
                Text(required ? "\(label) *" : label)
                    .font(DesignSystem.Font.subheadline)
                    .foregroundStyle(disabled ? Color.haDisabled : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            fields
            if let helper {
                Text(helper)
                    .font(.system(size: 12))
                    .foregroundStyle(disabled ? Color.haDisabled : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(disabled ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label ?? ""))
    }

    private var fields: some View {
        HStack(spacing: 0) {
            if enableDay {
                box(dayLabel, value: $value.days, max: nil, pad: 1)
                separator
            }
            box(hourLabel, value: $value.hours, max: hourMax, pad: 1)
            separator
            box(minuteLabel, value: $value.minutes, max: 59, pad: 2)
            if enableSecond {
                separator
                box(secondLabel, value: $value.seconds, max: 59, pad: 2)
                if enableMillisecond {
                    separator
                }
            }
            if enableMillisecond {
                box(millisecondLabel, value: $value.milliseconds, max: 999, pad: 3)
            }
            if format == .twelve {
                periodSelect
            }
            if showsClearButton {
                clearButton
            }
        }
        .frame(height: Self.rowHeight)
        .background(Color.haNeutralQuietFill)
        // Rounded at the top and square at the bottom, so the underline below reads as one
        // continuous rule under the whole row rather than as a border around each box.
        .clipShape(TopRoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.haDivider)
                .frame(height: DesignSystem.Border.Width.default)
        }
    }

    private var separator: some View {
        Text(":")
            .font(DesignSystem.Font.body)
            .foregroundStyle(.secondary)
            .frame(width: Self.separatorWidth)
    }

    private func box(_ caption: String, value: Binding<Int>, max: Int?, pad: Int) -> some View {
        VStack(spacing: .zero) {
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("", text: Self.textBinding(for: value, max: max, pad: pad))
                .font(DesignSystem.Font.body)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(disabled)
        }
        .padding(.horizontal, DesignSystem.Spaces.half)
        .padding(.vertical, DesignSystem.Spaces.one)
        .frame(width: Self.boxWidth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(caption))
    }

    /// The boxes are `type="number"` inputs in the frontend, which reject non-digits and clamp to
    /// `max` for free. A SwiftUI `TextField` does neither, so the same guarantees are applied here:
    /// anything that is not a digit is dropped, and the result is capped.
    private static func textBinding(for value: Binding<Int>, max: Int?, pad: Int) -> Binding<String> {
        Binding(
            get: { String(value.wrappedValue).leftPadded(to: pad) },
            set: { text in
                let digits = text.filter(\.isNumber)
                let entered = Int(digits) ?? 0
                value.wrappedValue = max.map { Swift.min(entered, $0) } ?? entered
            }
        )
    }

    private var periodSelect: some View {
        Menu {
            Picker("", selection: $value.period) {
                ForEach(HADayPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spaces.half) {
                Text(value.period.rawValue)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(Color.primary)
                MaterialDesignIconsImage(icon: .menuDownIcon, size: 18)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spaces.one)
        }
        .disabled(disabled)
    }

    private var clearButton: some View {
        Button {
            onClear?()
        } label: {
            MaterialDesignIconsImage(icon: .closeIcon, size: 18)
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.Spaces.five)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.dismissAlert))
    }
}

private extension String {
    /// `_formatValue` in the frontend, which pads with zeroes to a fixed width so the boxes do not
    /// jump between "5" and "05" as you type.
    func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: "0", count: width - count) + self
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
        HABaseTimeInput(value: .constant(HATimeComponents(hours: 14, minutes: 30)), label: "Time")
        HABaseTimeInput(
            value: .constant(HATimeComponents(hours: 2, minutes: 30, period: .pm)),
            label: "12-hour",
            format: .twelve
        )
        HABaseTimeInput(
            value: .constant(HATimeComponents(days: 1, hours: 2, minutes: 30, seconds: 15, milliseconds: 250)),
            label: "Everything",
            helper: "Days through milliseconds",
            enableDay: true,
            enableSecond: true,
            enableMillisecond: true,
            noHoursLimit: true,
            clearable: true
        )
    }
    .padding()
}

extension HABaseTimeInput: FrontendComponent {
    public static var frontendComponentName: String { "ha-base-time-input" }
}

#endif
