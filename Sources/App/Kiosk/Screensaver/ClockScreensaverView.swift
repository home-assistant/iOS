import Combine
import Shared
import SwiftUI

// MARK: - Clock Screensaver View

/// A screensaver view displaying time with optional date and HA entity data
public struct ClockScreensaverView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @ObservedObject private var entityProvider = EntityStateProvider.shared
    @State private var currentTime = Date()
    @State private var pixelShiftOffset: CGSize = .zero

    private let showEntities: Bool
    private let timeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(showEntities: Bool = false) {
        self.showEntities = showEntities
    }

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

                    if showEntities && !manager.settings.clockEntities.isEmpty {
                        entityDisplay
                            .offset(pixelShiftOffset)
                            .padding(.top, 40)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if showEntities {
                let entityIds = manager.settings.clockEntities.map(\.entityId)
                entityProvider.watchEntities(entityIds)
            }
        }
        .onDisappear {
            if showEntities {
                entityProvider.stopWatching()
            }
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kioskPixelShiftTick)) { _ in
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
            .font(.system(size: 120, weight: .thin, design: .rounded))
            .foregroundColor(.white)
            .monospacedDigit()
            .accessibilityLabel("Current time: \(accessibleTimeString)")
    }

    private var minimalClockDisplay: some View {
        Text(timeString)
            .font(.system(size: 80, weight: .ultraLight, design: .default))
            .foregroundColor(.white.opacity(0.9))
            .monospacedDigit()
            .accessibilityLabel("Current time: \(accessibleTimeString)")
    }

    private var digitalClockDisplay: some View {
        Text(timeString)
            .font(.system(size: 100, weight: .medium, design: .monospaced))
            .foregroundColor(.green)
            .monospacedDigit()
            .accessibilityLabel("Current time: \(accessibleTimeString)")
    }

    private var analogClockDisplay: some View {
        // Analog clock face
        AnalogClockView(date: currentTime)
            .frame(width: 300, height: 300)
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

    // MARK: - Entity Display

    private var entityDisplay: some View {
        HStack(spacing: 40) {
            ForEach(manager.settings.clockEntities.prefix(4)) { entity in
                EntityValueView(config: entity)
            }
        }
    }

    // MARK: - Pixel Shift

    private func applyPixelShift() {
        guard manager.settings.pixelShiftEnabled else { return }

        let amount = manager.settings.pixelShiftAmount

        withAnimation(.easeInOut(duration: 1.0)) {
            pixelShiftOffset = CGSize(
                width: CGFloat.random(in: -amount...amount),
                height: CGFloat.random(in: -amount...amount)
            )
        }
    }
}

// MARK: - Analog Clock View

struct AnalogClockView: View {
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
            ForEach(0..<12) { hour in
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: hour % 3 == 0 ? 3 : 1, height: hour % 3 == 0 ? 15 : 8)
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

// MARK: - Entity Value View

struct EntityValueView: View {
    let config: ClockEntityConfig
    @ObservedObject private var entityProvider = EntityStateProvider.shared

    private var entityState: EntityState? {
        entityProvider.state(for: config.entityId)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            iconView
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.7))
                .accessibilityHidden(true)

            // Value
            Text(displayValue)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .accessibilityHidden(true)

            // Label
            Text(displayLabel)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .accessibilityHidden(true)

            // Unit (if separate from value)
            if config.showUnit, let unit = entityState?.unitOfMeasurement, !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var description = displayLabel
        description += ": \(displayValue)"
        if config.showUnit, let unit = entityState?.unitOfMeasurement, !unit.isEmpty {
            description += " \(unit)"
        }
        return description
    }

    @ViewBuilder
    private var iconView: some View {
        let iconName = config.icon ?? entityState?.icon
        if let iconName {
            Image(systemName: IconMapper.sfSymbol(from: iconName, default: "sensor.fill"))
        } else {
            Image(systemName: "sensor.fill")
        }
    }

    private var displayValue: String {
        entityState?.value ?? "--"
    }

    private var displayLabel: String {
        config.label ?? entityState?.friendlyName ?? config.entityId
    }
}

// MARK: - Preview

#Preview("Large Clock") {
    ClockScreensaverView(showEntities: false)
}

#Preview("Clock with Entities") {
    ClockScreensaverView(showEntities: true)
}
