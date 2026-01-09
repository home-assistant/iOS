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

                    if manager.settings.clockShowWeather && !manager.settings.clockWeatherEntity.isEmpty {
                        weatherDisplay
                            .offset(pixelShiftOffset)
                            .padding(.top, 20)
                    }

                    if showEntities && !manager.settings.clockEntities.isEmpty {
                        entityDisplay
                            .offset(pixelShiftOffset)
                            .padding(.top, manager.settings.clockShowWeather ? 20 : 40)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            startWatchingEntities()
        }
        .onDisappear {
            entityProvider.stopWatching()
        }
        .onReceive(timeTimer) { _ in
            currentTime = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kioskPixelShiftTick)) { _ in
            applyPixelShift()
        }
    }

    private func startWatchingEntities() {
        var entityIds: [String] = []

        // Add weather entities
        if manager.settings.clockShowWeather {
            if !manager.settings.clockWeatherEntity.isEmpty {
                entityIds.append(manager.settings.clockWeatherEntity)
            }
            if !manager.settings.clockTemperatureEntity.isEmpty {
                entityIds.append(manager.settings.clockTemperatureEntity)
            }
        }

        // Add clock entities
        if showEntities {
            entityIds.append(contentsOf: manager.settings.clockEntities.map(\.entityId))
        }

        if !entityIds.isEmpty {
            entityProvider.watchEntities(entityIds)
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

    // MARK: - Weather Display

    private var weatherDisplay: some View {
        HStack(spacing: 16) {
            // Weather icon
            weatherIcon
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 4) {
                // Temperature
                Text(temperatureString)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(.white)

                // Condition
                Text(weatherCondition)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather: \(temperatureString), \(weatherCondition)")
    }

    private var weatherState: EntityState? {
        entityProvider.state(for: manager.settings.clockWeatherEntity)
    }

    private var temperatureState: EntityState? {
        let tempEntity = manager.settings.clockTemperatureEntity
        if !tempEntity.isEmpty {
            return entityProvider.state(for: tempEntity)
        }
        return nil
    }

    private var temperatureString: String {
        // Prefer dedicated temperature sensor if configured
        if let tempState = temperatureState {
            let temp = tempState.state
            let unit = tempState.unitOfMeasurement ?? "°"
            return "\(temp)\(unit)"
        }

        // Fall back to weather entity temperature
        if let weather = weatherState,
           let temp = weather.entityId.isEmpty ? nil : (entityProvider.entityStates[manager.settings.clockWeatherEntity]) {
            // Weather entities store temperature in attributes
            if let attributes = getWeatherAttributes(),
               let temperature = attributes["temperature"] as? Double {
                let unit = attributes["temperature_unit"] as? String ?? "°F"
                return String(format: "%.0f%@", temperature, unit)
            }
        }

        return "--°"
    }

    private var weatherCondition: String {
        weatherState?.state.capitalized ?? "Unknown"
    }

    @ViewBuilder
    private var weatherIcon: some View {
        let condition = weatherState?.state.lowercased() ?? ""
        Image(systemName: weatherIconName(for: condition))
    }

    private func weatherIconName(for condition: String) -> String {
        switch condition {
        case "sunny", "clear", "clear-night":
            return condition.contains("night") ? "moon.stars.fill" : "sun.max.fill"
        case "partlycloudy", "partly_cloudy":
            return "cloud.sun.fill"
        case "cloudy":
            return "cloud.fill"
        case "rainy", "rain", "pouring":
            return "cloud.rain.fill"
        case "snowy", "snow", "snowy-rainy":
            return "cloud.snow.fill"
        case "windy", "wind":
            return "wind"
        case "fog", "foggy", "hazy":
            return "cloud.fog.fill"
        case "lightning", "lightning-rainy", "thunderstorm":
            return "cloud.bolt.rain.fill"
        case "hail":
            return "cloud.hail.fill"
        case "exceptional":
            return "exclamationmark.triangle.fill"
        default:
            return "cloud.fill"
        }
    }

    private func getWeatherAttributes() -> [String: Any]? {
        // This would need access to the raw HAEntity attributes
        // For now, return nil - the temperature entity is the better approach
        return nil
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
            Text(formattedValue)
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        "\(displayLabel): \(formattedValue)"
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

    private var formattedValue: String {
        guard let state = entityState else { return "--" }

        let rawValue = state.state
        let unit = config.suffix ?? (config.showUnit ? state.unitOfMeasurement : nil)
        let prefix = config.prefix ?? ""

        // Try to parse as number for formatting
        let numericValue = Double(rawValue)

        switch config.displayFormat {
        case .auto:
            return formatAuto(rawValue: rawValue, numericValue: numericValue, unit: unit, prefix: prefix)

        case .value:
            return "\(prefix)\(rawValue)"

        case .valueWithUnit:
            if let unit = unit, !unit.isEmpty {
                return "\(prefix)\(formatNumber(numericValue, rawValue: rawValue))\(unit)"
            }
            return "\(prefix)\(formatNumber(numericValue, rawValue: rawValue))"

        case .valueSpaceUnit:
            if let unit = unit, !unit.isEmpty {
                return "\(prefix)\(formatNumber(numericValue, rawValue: rawValue)) \(unit)"
            }
            return "\(prefix)\(formatNumber(numericValue, rawValue: rawValue))"

        case .integer:
            if let num = numericValue {
                return "\(prefix)\(Int(num.rounded()))\(unit ?? "")"
            }
            return "\(prefix)\(rawValue)"

        case .percentage:
            if let num = numericValue {
                return "\(prefix)\(Int(num.rounded()))%"
            }
            return "\(prefix)\(rawValue)%"

        case .compact:
            if let num = numericValue {
                return "\(prefix)\(formatCompact(num))\(unit ?? "")"
            }
            return "\(prefix)\(rawValue)"

        case .time:
            if let num = numericValue {
                return formatDuration(num)
            }
            return rawValue
        }
    }

    private func formatAuto(rawValue: String, numericValue: Double?, unit: String?, prefix: String) -> String {
        // Auto formatting based on entity type and unit
        if let num = numericValue {
            // Temperature - no space before degree symbol
            if let unit = unit, (unit.contains("°") || unit.contains("C") || unit.contains("F")) {
                let formatted = formatNumber(num, decimalPlaces: config.decimalPlaces ?? 0)
                return "\(prefix)\(formatted)\(unit)"
            }

            // Percentage
            if let unit = unit, unit == "%" {
                return "\(prefix)\(Int(num.rounded()))%"
            }

            // Other numeric with unit
            if let unit = unit, !unit.isEmpty {
                let formatted = formatNumber(num, decimalPlaces: config.decimalPlaces)
                return "\(prefix)\(formatted) \(unit)"
            }

            // Plain numeric
            let formatted = formatNumber(num, decimalPlaces: config.decimalPlaces)
            return "\(prefix)\(formatted)"
        }

        // Non-numeric state (on/off, etc.)
        return "\(prefix)\(rawValue.capitalized)"
    }

    private func formatNumber(_ value: Double?, rawValue: String? = nil, decimalPlaces: Int? = nil) -> String {
        guard let value = value else { return rawValue ?? "--" }

        if let places = decimalPlaces ?? config.decimalPlaces {
            return String(format: "%.\(places)f", value)
        }

        // Auto decimal places
        if value == value.rounded() {
            return String(Int(value))
        } else if abs(value) < 10 {
            return String(format: "%.1f", value)
        } else {
            return String(Int(value.rounded()))
        }
    }

    private func formatCompact(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        if absValue >= 1_000_000_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 1_000_000_000))B"
        } else if absValue >= 1_000_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 1_000_000))M"
        } else if absValue >= 1_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 1_000))K"
        } else {
            return formatNumber(value)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
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
