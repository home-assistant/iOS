import Combine
import SwiftUI

// MARK: - Kiosk Clock Screensaver View

/// A screensaver view displaying time with optional date
/// TODO: Add entity display support
public struct KioskClockScreensaverView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @State private var currentTime = Date()
    @State private var pixelShiftOffset: CGSize = .zero

    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        GeometryReader { _ in
            ZStack {
                // Background
                Color.black
                    .edgesIgnoringSafeArea(.all)

                // Clock content
                VStack(spacing: 20) {
                    Spacer()

                    clockDisplay
                        .offset(pixelShiftOffset)

                    if manager.settings.clockShowDate {
                        dateDisplay
                            .offset(pixelShiftOffset)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onChange(of: manager.pixelShiftTrigger) { _ in
            applyPixelShift()
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
            .accessibilityLabel("Current time: \(accessibleTimeString)")
    }

    private var minimalClockDisplay: some View {
        Text(timeString)
            .font(.system(size: KioskConstants.UI.minimalClockFontSize, weight: .ultraLight, design: .default))
            .foregroundColor(.white.opacity(0.9))
            .monospacedDigit()
            .accessibilityLabel("Current time: \(accessibleTimeString)")
    }

    private var digitalClockDisplay: some View {
        Text(timeString)
            .font(.system(size: KioskConstants.UI.digitalClockFontSize, weight: .medium, design: .monospaced))
            .foregroundColor(.green)
            .monospacedDigit()
            .accessibilityLabel("Current time: \(accessibleTimeString)")
    }

    private var analogClockDisplay: some View {
        KioskAnalogClockView(date: currentTime)
            .frame(
                width: KioskConstants.UI.analogClockSize,
                height: KioskConstants.UI.analogClockSize
            )
            .accessibilityLabel("Analog clock showing \(accessibleTimeString)")
    }

    private var timeString: String {
        let formatter = DateFormatter()
        let use24Hour = manager.settings.clockUse24HourFormat
        let showSeconds = manager.settings.clockShowSeconds

        if use24Hour {
            formatter.dateFormat = showSeconds ? "HH:mm:ss" : "HH:mm"
        } else {
            formatter.dateFormat = showSeconds ? "h:mm:ss a" : "h:mm a"
        }
        return formatter.string(from: currentTime)
    }

    private var accessibleTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: currentTime)
    }

    // MARK: - Date Display

    private var dateDisplay: some View {
        Text(dateString)
            .font(.system(size: 28, weight: .light, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .accessibilityLabel("Date: \(dateString)")
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }

    // MARK: - Pixel Shift

    private func applyPixelShift() {
        guard manager.settings.pixelShiftEnabled else { return }

        let amount = manager.settings.pixelShiftAmount

        withAnimation(.easeInOut(duration: KioskConstants.Animation.pixelShift)) {
            pixelShiftOffset = CGSize(
                width: CGFloat.random(in: -amount ... amount),
                height: CGFloat.random(in: -amount ... amount)
            )
        }
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
