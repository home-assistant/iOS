import Shared
import SwiftUI

// MARK: - Kiosk Date Formatters

/// Cached date formatters for clock display, reusable across the app
enum KioskDateFormatters {
    static let time24h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let time24hSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static let time12h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static let time12hSeconds: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm:ss a"
        return f
    }()

    static let accessibility: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    static let dateDisplay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return f
    }()
}

// MARK: - Kiosk Clock Screensaver View

/// A screensaver view displaying time with optional date
public struct KioskClockScreensaverView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @State private var currentTime = Current.date()
    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        GeometryReader { _ in
            VStack(spacing: DesignSystem.Spaces.two) {
                Spacer()

                clockDisplay

                if manager.settings.clockShowDate {
                    dateDisplay
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .onReceive(timeTimer) { _ in
            currentTime = Current.date()
        }
    }

    // MARK: - Clock Display

    @ViewBuilder
    private var clockDisplay: some View {
        switch manager.settings.clockStyle {
        case .large:
            largeClockDisplay

        case .minimal:
            minimalClockDisplay

        case .analog:
            analogClockDisplay

        case .digital:
            digitalClockDisplay
        }
    }

    private var largeClockDisplay: some View {
        Text(timeString)
            .font(.system(size: KioskConstants.UI.largeClockFontSize, weight: .thin, design: .rounded))
            .foregroundColor(.white)
            .monospacedDigit()
            .accessibilityLabel(L10n.Kiosk.Clock.Accessibility.currentTime(accessibleTimeString))
    }

    private var minimalClockDisplay: some View {
        Text(timeString)
            .font(.system(size: KioskConstants.UI.minimalClockFontSize, weight: .ultraLight, design: .default))
            .foregroundColor(.white.opacity(0.9))
            .monospacedDigit()
            .accessibilityLabel(L10n.Kiosk.Clock.Accessibility.currentTime(accessibleTimeString))
    }

    private var digitalClockDisplay: some View {
        Text(timeString)
            .font(.system(size: KioskConstants.UI.digitalClockFontSize, weight: .medium, design: .monospaced))
            .foregroundColor(.green)
            .monospacedDigit()
            .accessibilityLabel(L10n.Kiosk.Clock.Accessibility.currentTime(accessibleTimeString))
    }

    private var analogClockDisplay: some View {
        KioskAnalogClockView(date: currentTime)
            .frame(
                width: KioskConstants.UI.analogClockSize,
                height: KioskConstants.UI.analogClockSize
            )
            .accessibilityLabel(L10n.Kiosk.Clock.Accessibility.analogClock(accessibleTimeString))
    }

    private var timeString: String {
        let use24Hour = manager.settings.clockUse24HourFormat
        let showSeconds = manager.settings.clockShowSeconds

        let formatter: DateFormatter
        if use24Hour {
            formatter = showSeconds ? KioskDateFormatters.time24hSeconds : KioskDateFormatters.time24h
        } else {
            formatter = showSeconds ? KioskDateFormatters.time12hSeconds : KioskDateFormatters.time12h
        }
        return formatter.string(from: currentTime)
    }

    private var accessibleTimeString: String {
        KioskDateFormatters.accessibility.string(from: currentTime)
    }

    // MARK: - Date Display

    private var dateDisplay: some View {
        Text(dateString)
            .font(.system(size: 28, weight: .light, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .accessibilityLabel(L10n.Kiosk.Clock.Accessibility.date(dateString))
    }

    private var dateString: String {
        KioskDateFormatters.dateDisplay.string(from: currentTime)
    }
}

// MARK: - Kiosk Analog Clock View

struct KioskAnalogClockView: View {
    let date: Date

    private var calendar: Calendar { Calendar.current }

    private var hours: Int {
        calendar.component(.hour, from: date) % 12
    }

    private var minutes: Int {
        calendar.component(.minute, from: date)
    }

    private var seconds: Int {
        calendar.component(.second, from: date)
    }

    var body: some View {
        ZStack {
            // Clock face
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .accessibilityHidden(true)

            // Hour markers
            ForEach(0 ..< 12, id: \.self) { hour in
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: hour.isMultiple(of: 3) ? 3 : 1, height: hour.isMultiple(of: 3) ? 15 : 8)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(hour) * 30))
                    .accessibilityHidden(true)
            }

            // Hour hand
            Rectangle()
                .fill(Color.white)
                .frame(width: 4, height: 70)
                .offset(y: -35)
                .rotationEffect(.degrees(Double(hours) * 30 + Double(minutes) * 0.5))
                .accessibilityHidden(true)

            // Minute hand
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 100)
                .offset(y: -50)
                .rotationEffect(.degrees(Double(minutes) * 6))
                .accessibilityHidden(true)

            // Second hand
            Rectangle()
                .fill(Color.red)
                .frame(width: 1, height: 110)
                .offset(y: -55)
                .rotationEffect(.degrees(Double(seconds) * 6))
                .accessibilityHidden(true)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
    }
}

// MARK: - Preview

#Preview("Large Clock") {
    KioskClockScreensaverView()
        .preferredColorScheme(.dark)
}
