#if !os(watchOS)
import HAIconic
import SwiftUI

/// Current conditions over a row of forecast columns. The SwiftUI counterpart of the frontend's
/// `hui-weather-forecast-card`.
public struct HAWeatherForecastCard: View {
    private let name: String
    private let icon: MaterialDesignIcons
    private let temperature: String
    private let condition: String?
    private let attributes: [String]
    private let forecast: [HAWeatherForecastEntry]

    /// - Parameter attributes: Short readings under the condition — pressure, humidity, wind — as
    ///   already-formatted strings.
    public init(
        name: String,
        icon: MaterialDesignIcons,
        temperature: String,
        condition: String? = nil,
        attributes: [String] = [],
        forecast: [HAWeatherForecastEntry] = []
    ) {
        self.name = name
        self.icon = icon
        self.temperature = temperature
        self.condition = condition
        self.attributes = attributes
        self.forecast = forecast
    }

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.two) {
                HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                    MaterialDesignIconsImage(icon: icon, size: 48)
                        .foregroundStyle(.haPrimary)
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                        Text(temperature)
                            .font(.system(size: 28))
                        Text(name)
                            .font(DesignSystem.Font.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: .zero)
                    VStack(alignment: .trailing, spacing: DesignSystem.Spaces.micro) {
                        if let condition {
                            Text(condition)
                                .font(DesignSystem.Font.body)
                        }
                        ForEach(attributes, id: \.self) { attribute in
                            Text(attribute)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !forecast.isEmpty {
                    Divider()
                    HStack(alignment: .top, spacing: .zero) {
                        ForEach(forecast) { entry in
                            VStack(spacing: DesignSystem.Spaces.half) {
                                Text(entry.label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                MaterialDesignIconsImage(icon: entry.icon, size: 24)
                                    .foregroundStyle(.haPrimary)
                                Text(entry.high)
                                    .font(.system(size: 12, weight: .medium))
                                if let low = entry.low {
                                    Text(low)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

private let sampleForecast = [
    HAWeatherForecastEntry(id: "1", label: "Mon", icon: .weatherSunnyIcon, high: "24°", low: "14°"),
    HAWeatherForecastEntry(id: "2", label: "Tue", icon: .weatherPartlyCloudyIcon, high: "22°", low: "13°"),
    HAWeatherForecastEntry(id: "3", label: "Wed", icon: .weatherRainyIcon, high: "18°", low: "12°"),
    HAWeatherForecastEntry(id: "4", label: "Thu", icon: .weatherCloudyIcon, high: "19°", low: "11°"),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAWeatherForecastCard(
            name: "Home",
            icon: .weatherPartlyCloudyIcon,
            temperature: "21 °C",
            condition: "Partly cloudy",
            attributes: ["1013 hPa", "64 %", "12 km/h"],
            forecast: sampleForecast
        )
        HAWeatherForecastCard(name: "Home", icon: .weatherSunnyIcon, temperature: "24 °C")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAWeatherForecastCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-weather-forecast-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
