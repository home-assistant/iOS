#if !os(watchOS)
import SwiftUI

/// An analog clock face. The SwiftUI counterpart of the frontend's `hui-clock-card-analog`.
///
/// The time is a parameter rather than read from the clock, for the reason ``HARelativeTime`` takes
/// one: a view that ticked itself could not be snapshotted, and the caller usually has a `now` from
/// its own refresh already.
public struct HAAnalogClock: View {
    /// Which marks go around the dial, the frontend's `ticks` config.
    public enum Ticks: Sendable {
        case none
        /// Four marks, at 12, 3, 6 and 9.
        case quarter
        /// Twelve marks, one an hour.
        case hour
        /// Sixty marks, one a minute, with the hours drawn longer.
        case minute
    }

    /// How the hours are written when numerals are shown.
    public enum Numerals: Sendable {
        case none
        case arabic
        case roman
    }

    /// Proportions of the dial's diameter, from the frontend's stylesheet: the hour hand is a
    /// quarter of it, the minute hand 35% and the second hand 42%.
    private static let hourHandLength: CGFloat = 0.25
    private static let minuteHandLength: CGFloat = 0.35
    private static let secondHandLength: CGFloat = 0.42
    private static let centerDotSize: CGFloat = 8

    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone

    private let date: Date
    private let diameter: CGFloat
    private let ticks: Ticks
    private let numerals: Numerals
    private let showsSeconds: Bool

    /// - Parameter diameter: Explicit, for the reason ``HAGauge`` takes one — a dial sized from its
    ///   container collapses to nothing when the height proposal is unbounded.
    public init(
        date: Date,
        diameter: CGFloat = 180,
        ticks: Ticks = .hour,
        numerals: Numerals = .none,
        showsSeconds: Bool = false
    ) {
        self.date = date
        self.diameter = diameter
        self.ticks = ticks
        self.numerals = numerals
        self.showsSeconds = showsSeconds
    }

    /// Fractional hours, minutes and seconds, so the hands sit between marks rather than jumping
    /// between them — at half past, the hour hand belongs halfway to the next hour.
    private var components: (hour: Double, minute: Double, second: Double) {
        var readingCalendar = calendar
        readingCalendar.timeZone = timeZone
        let parts = readingCalendar.dateComponents([.hour, .minute, .second], from: date)
        let second = Double(parts.second ?? 0)
        let minute = Double(parts.minute ?? 0) + second / 60
        let hour = Double((parts.hour ?? 0) % 12) + minute / 60
        return (hour, minute, second)
    }

    public var body: some View {
        ZStack {
            tickMarks
            numeralLabels
            hands
            Circle()
                .fill(Color.primary)
                .frame(width: Self.centerDotSize, height: Self.centerDotSize)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        // Spelled out in the injected zone, like the hands are. The shorthand formatter uses the
        // process zone, so a dial rendered for another zone would be read out as a different time
        // from the one it is showing.
        .accessibilityLabel(Text(date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)
        )))
    }

    // MARK: - Dial

    private var tickAngles: [Double] {
        switch ticks {
        case .none: []
        case .quarter: [0, 90, 180, 270]
        case .hour: (0 ..< 12).map { Double($0) * 30 }
        case .minute: (0 ..< 60).map { Double($0) * 6 }
        }
    }

    private func tickLength(at angle: Double) -> CGFloat {
        // On a minute dial the hours stay long so the quarters remain readable at a glance; the
        // frontend gives them 3% of the dial against 1.5% for the rest.
        if ticks == .minute {
            return angle.truncatingRemainder(dividingBy: 30) == 0 ? diameter * 0.03 : diameter * 0.015
        }
        return diameter * 0.04
    }

    private func tickWidth(at angle: Double) -> CGFloat {
        ticks == .minute && angle.truncatingRemainder(dividingBy: 30) != 0 ? 1 : 2
    }

    private var tickMarks: some View {
        ForEach(tickAngles, id: \.self) { angle in
            Capsule()
                .fill(Color.primary)
                .frame(width: tickWidth(at: angle), height: tickLength(at: angle))
                .offset(y: -diameter / 2 + tickLength(at: angle) / 2 + DesignSystem.Spaces.half)
                .rotationEffect(.degrees(angle))
        }
    }

    private var numeralLabels: some View {
        ForEach(numerals == .none ? [] : Array(1 ... 12), id: \.self) { hour in
            Text(Self.numeral(hour, style: numerals))
                .font(.system(size: diameter * 0.09))
                .foregroundStyle(Color.primary)
                // Counter-rotated so every numeral stays upright, as the frontend's transform does.
                .rotationEffect(.degrees(-Double(hour) * 30))
                .offset(y: -diameter / 2 + diameter * 0.13)
                .rotationEffect(.degrees(Double(hour) * 30))
        }
    }

    private var hands: some View {
        ZStack {
            hand(
                length: Self.hourHandLength,
                width: 4,
                angle: components.hour * 30,
                color: .primary
            )
            hand(
                length: Self.minuteHandLength,
                width: 3,
                angle: components.minute * 6,
                color: .primary
            )
            .opacity(0.9)
            if showsSeconds {
                hand(
                    length: Self.secondHandLength,
                    width: 2,
                    angle: components.second * 6,
                    color: .haErrorColor
                )
                .opacity(0.8)
            }
        }
    }

    /// A hand pivots at the centre of the dial, so it is drawn as a bar whose lower end sits there
    /// and then rotated about that point.
    private func hand(length: CGFloat, width: CGFloat, angle: Double, color: Color) -> some View {
        let handLength = diameter * length
        return Capsule()
            .fill(color)
            .frame(width: width, height: handLength)
            .offset(y: -handLength / 2)
            .rotationEffect(.degrees(angle))
    }

    private static func numeral(_ hour: Int, style: Numerals) -> String {
        switch style {
        case .none: ""
        case .arabic: String(hour)
        case .roman: romanNumerals[hour - 1]
        }
    }

    private static let romanNumerals = [
        "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII",
    ]
}

/// 2026-08-29 10:09:37 UTC — a time whose hands sit at three clearly different angles.
private let sampleTime = Date(timeIntervalSince1970: 1_787_998_177)

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAAnalogClock(date: sampleTime)
        HAAnalogClock(date: sampleTime, diameter: 140, ticks: .minute, showsSeconds: true)
        HAAnalogClock(date: sampleTime, diameter: 140, ticks: .quarter, numerals: .roman)
    }
    .padding()
    .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .gmt)
}

extension HAAnalogClock: FrontendComponent {
    public static var frontendComponentName: String { "hui-clock-card-analog" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
