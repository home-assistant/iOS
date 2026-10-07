#if !os(watchOS)
import SwiftUI

/// A large reading with its decimals and unit set small beside it — the number a thermostat or
/// humidifier card leads with. The SwiftUI counterpart of the frontend's `ha-big-number`.
///
/// The integer part is drawn at full size; the fraction and unit ride alongside it at a fraction of
/// that, so `21.5 °C` reads as one glyph cluster rather than three sizes competing.
public struct HABigNumber: View {
    /// Where the unit sits relative to the decimals, matching `ha-big-number`'s `unit-position`.
    public enum UnitPosition: String, CaseIterable, Sendable {
        /// Unit above the decimals, stacked in a column. The frontend's default.
        case top
        /// Unit trailing the decimals on the baseline.
        case bottom
    }

    /// Formatting follows the environment's locale rather than `Locale.current`, so a caller — or a
    /// snapshot test — can pin it.
    @Environment(\.locale) private var locale
    private let value: Double
    private let unit: String?
    private let unitPosition: UnitPosition
    private let fractionLength: Int
    private let size: CGFloat

    /// - Parameters:
    ///   - fractionLength: How many decimals to show. The frontend takes `Intl.NumberFormatOptions`;
    ///     this is the part of it a reading actually varies.
    ///   - size: The integer part's point size. `ha-big-number` fixes this at 57px; cards that need
    ///     a smaller number override it.
    public init(
        value: Double,
        unit: String? = nil,
        unitPosition: UnitPosition = .top,
        fractionLength: Int = 1,
        size: CGFloat = 57
    ) {
        self.value = value
        self.unit = unit
        self.unitPosition = unitPosition
        self.fractionLength = fractionLength
        self.size = size
    }

    /// The formatted number split at the locale's decimal separator, so the two parts can be set at
    /// different sizes without re-formatting either.
    private var parts: (integer: String, fraction: String) {
        let formatted = value.formatted(.number.precision(.fractionLength(fractionLength)).locale(locale))
        let separator = locale.decimalSeparator ?? "."
        guard let range = formatted.range(of: separator) else { return (formatted, "") }
        return (String(formatted[formatted.startIndex ..< range.lowerBound]), String(formatted[range.lowerBound...]))
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: .zero) {
            Text(parts.integer)
                .font(.system(size: size))
            // `.addon` in the frontend. The two positions differ in child order as well as axis —
            // a reversed column puts the unit above the decimals, a row puts it after them — so
            // they are spelled out rather than swapping a layout under one set of children.
            switch unitPosition {
            case .top:
                VStack(alignment: .leading, spacing: .zero) {
                    if let unit {
                        Text(unit)
                            .font(.system(size: size * 0.33))
                    }
                    if !parts.fraction.isEmpty {
                        Text(parts.fraction)
                            .font(.system(size: size * 0.42))
                    }
                }
                .padding(.vertical, DesignSystem.Spaces.half)
            case .bottom:
                HStack(alignment: .lastTextBaseline, spacing: DesignSystem.Spaces.micro) {
                    if !parts.fraction.isEmpty {
                        Text(parts.fraction)
                            .font(.system(size: size * 0.42))
                    }
                    if let unit {
                        Text(unit)
                            .font(.system(size: size * 0.33))
                    }
                }
                .padding(.vertical, DesignSystem.Spaces.half)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(parts.integer)\(parts.fraction) \(unit ?? "")"))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.three) {
        HABigNumber(value: 21.5, unit: "°C")
        HABigNumber(value: 21.5, unit: "°C", unitPosition: .bottom)
        HABigNumber(value: 64, unit: "%", fractionLength: 0)
        HABigNumber(value: 1013.25, unit: "hPa", fractionLength: 2, size: 34)
        HABigNumber(value: 7)
    }
    .padding()
}

extension HABigNumber: FrontendComponent {
    public static var frontendComponentName: String { "ha-big-number" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
