#if !os(watchOS)
import Foundation
import HAIconic

/// One column of an ``HAWeatherForecastCard``.
///
/// The label is a plain string rather than a date, because whether a column reads "Mon" or "15:00"
/// depends on the forecast's granularity — daily or hourly — which is the app's to decide.
///
/// Frontend counterpart: the `ForecastAttribute` data `hui-weather-forecast-card` renders, rather
/// than an element of its own.
public struct HAWeatherForecastEntry: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let icon: MaterialDesignIcons
    public let high: String
    public let low: String?

    public init(id: String, label: String, icon: MaterialDesignIcons, high: String, low: String? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
        self.high = high
        self.low = low
    }
}

extension HAWeatherForecastEntry: FrontendComponent {
    public static var frontendComponentName: String { "hui-weather-forecast-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
