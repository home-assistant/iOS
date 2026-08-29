#if !os(watchOS)
import SwiftUI

/// A clock on a card. The SwiftUI counterpart of the frontend's `hui-clock-card`.
///
/// The instant is a parameter rather than read from the system: a clock that fetched the time itself
/// would render differently on every pass, so the caller owns the ticking — and the gallery can hold
/// it at a fixed moment.
public struct HAClockCard: View {
    /// The frontend's `clock_size`, in the point sizes it maps to.
    public enum Size: CGFloat, CaseIterable, Sendable {
        case small = 34
        case medium = 48
        case large = 68
    }

    @Environment(\.locale) private var locale
    private let date: Date
    private let title: String?
    private let size: Size
    private let showsSeconds: Bool
    private let showsDate: Bool
    private let timeZone: TimeZone
    private let showsBackground: Bool

    /// - Parameter showsBackground: Passing `false` drops the card surface, the frontend's
    ///   `no_background` — for a clock sitting on a dashboard that already has one.
    public init(
        date: Date,
        title: String? = nil,
        size: Size = .medium,
        showsSeconds: Bool = false,
        showsDate: Bool = false,
        timeZone: TimeZone = .current,
        showsBackground: Bool = true
    ) {
        self.date = date
        self.title = title
        self.size = size
        self.showsSeconds = showsSeconds
        self.showsDate = showsDate
        self.timeZone = timeZone
        self.showsBackground = showsBackground
    }

    /// The locale and zone go through the style's initialiser: the `.timeZone(_:)` builder names a
    /// zone *symbol* to print, not the zone the time is rendered in.
    private var baseStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: timeZone)
    }

    private var timeText: String {
        // `.second(.omitted)` is iOS 18, so seconds are added by not asking for them rather than by
        // asking for none.
        let style = baseStyle.hour().minute()
        return date.formatted(showsSeconds ? style.second(.twoDigits) : style)
    }

    private var dateText: String {
        date.formatted(baseStyle.weekday(.wide).day().month(.wide))
    }

    public var body: some View {
        let clock = VStack(spacing: DesignSystem.Spaces.half) {
            if let title {
                Text(title)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
            }
            Text(timeText)
                .font(.system(size: size.rawValue, weight: .medium))
                // Digits of equal width, so the clock does not jitter as the minute changes.
                .monospacedDigit()
            if showsDate {
                Text(dateText)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spaces.two)
        .accessibilityElement(children: .combine)

        if showsBackground {
            HACard { clock }
        } else {
            clock
        }
    }
}

/// 2026-08-29 09:41:07 UTC, so the previews and the recorded images read the same every time.
private let sampleClockDate = Date(timeIntervalSince1970: 1_787_996_467)

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAClockCard(date: sampleClockDate, timeZone: TimeZone(identifier: "UTC")!)
        HAClockCard(date: sampleClockDate, title: "Home", size: .large, timeZone: TimeZone(identifier: "UTC")!)
        HAClockCard(
            date: sampleClockDate,
            size: .small,
            showsSeconds: true,
            showsDate: true,
            timeZone: TimeZone(identifier: "UTC")!
        )
        HAClockCard(date: sampleClockDate, timeZone: TimeZone(identifier: "UTC")!, showsBackground: false)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAClockCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-clock-card" }
}

#endif
