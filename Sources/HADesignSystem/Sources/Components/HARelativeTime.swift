#if !os(watchOS)
import SwiftUI

/// How long ago something happened, in words — "5 minutes ago". The SwiftUI counterpart of the
/// frontend's `ha-relative-time`.
///
/// Both instants are parameters: `date` and the `now` it is measured against. A component that read
/// the clock itself would render differently on every pass, and the caller usually has a `now` from
/// its own refresh anyway.
public struct HARelativeTime: View {
    /// How much the wording is abbreviated, mirroring `RelativeDateTimeFormatter`'s styles.
    public enum Style: Sendable {
        case full
        case short

        var formatterStyle: RelativeDateTimeFormatter.UnitsStyle {
            switch self {
            case .full: .full
            case .short: .short
            }
        }
    }

    @Environment(\.locale) private var locale
    private let date: Date
    private let now: Date
    private let style: Style

    public init(date: Date, now: Date, style: Style = .full) {
        self.date = date
        self.now = now
        self.style = style
    }

    /// `Date.RelativeFormatStyle` always measures against the current instant, so the reference date
    /// goes through `RelativeDateTimeFormatter`, which takes one.
    private var text: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = style.formatterStyle
        return formatter.localizedString(for: date, relativeTo: now)
    }

    public var body: some View {
        Text(text)
    }
}

/// 2026-08-29 09:41:07 UTC, the same instant the clock card pins.
private let sampleNow = Date(timeIntervalSince1970: 1_787_996_467)

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
        HARelativeTime(date: sampleNow.addingTimeInterval(-60), now: sampleNow)
        HARelativeTime(date: sampleNow.addingTimeInterval(-3600), now: sampleNow)
        HARelativeTime(date: sampleNow.addingTimeInterval(-86400 * 3), now: sampleNow)
        HARelativeTime(date: sampleNow.addingTimeInterval(3600), now: sampleNow)
        HARelativeTime(date: sampleNow.addingTimeInterval(-3600), now: sampleNow, style: .short)
    }
    .padding()
}

extension HARelativeTime: FrontendComponent {
    public static var frontendComponentName: String { "ha-relative-time" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
