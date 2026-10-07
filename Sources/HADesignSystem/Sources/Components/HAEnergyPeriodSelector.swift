#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// The energy dashboard's period bar: arrows either side of the span being shown, the choice of how
/// long that span is, and a toggle for comparing it with the one before. The SwiftUI counterpart of
/// the frontend's `hui-energy-period-selector`, which is all `hui-energy-date-selection-card` holds.
///
/// The label is a formatted string rather than a date range: what reads well — "August 2026",
/// "This week", "29 Aug" — depends on the period and the locale, and that is the app's call.
public struct HAEnergyPeriodSelector: View {
    private let label: String
    private let periods: [HAToggleButton]
    private let allowsCompare: Bool
    private let onPrevious: () -> Void
    private let onNext: () -> Void
    @Binding private var period: String?
    @Binding private var isComparing: Bool

    /// - Parameter allowsCompare: The frontend hides the toggle when the card sets
    ///   `disable_compare`.
    public init(
        label: String,
        periods: [HAToggleButton],
        period: Binding<String?>,
        isComparing: Binding<Bool> = .constant(false),
        allowsCompare: Bool = true,
        onPrevious: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {}
    ) {
        self.label = label
        self.periods = periods
        _period = period
        _isComparing = isComparing
        self.allowsCompare = allowsCompare
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Button(action: onPrevious) {
                        Image(systemSymbol: .chevronLeft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.previousPeriod))
                    Text(label)
                        .font(DesignSystem.Font.headline)
                        .frame(maxWidth: .infinity)
                    Button(action: onNext) {
                        Image(systemSymbol: .chevronRight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.nextPeriod))
                }
                HAButtonToggleGroup(buttons: periods, selection: $period, fullWidth: true)
                if allowsCompare {
                    HAFormField(
                        label: HADesignSystemEnvironment.current.strings.compareWithPreviousPeriod,
                        controlLeading: false
                    ) {
                        Toggle("", isOn: $isComparing).labelsHidden()
                    }
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

private let samplePeriods = [
    HAToggleButton(id: "day", label: "Day"),
    HAToggleButton(id: "week", label: "Week"),
    HAToggleButton(id: "month", label: "Month"),
    HAToggleButton(id: "year", label: "Year"),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAEnergyPeriodSelector(
            label: "August 2026",
            periods: samplePeriods,
            period: .constant("month")
        )
        HAEnergyPeriodSelector(
            label: "29 August 2026",
            periods: samplePeriods,
            period: .constant("day"),
            isComparing: .constant(true)
        )
        HAEnergyPeriodSelector(
            label: "2026",
            periods: samplePeriods,
            period: .constant("year"),
            allowsCompare: false
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAEnergyPeriodSelector: FrontendComponent {
    public static var frontendComponentName: String { "hui-energy-period-selector" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
