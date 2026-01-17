import Foundation

// MARK: - Icon Mapper

/// Utility for mapping Material Design Icons (MDI) to SF Symbols
public enum IconMapper {
    /// Comprehensive mapping of MDI icons to SF Symbols
    public static let mdiToSFSymbol: [String: String] = [
        // General
        "mdi:application": "app.fill",
        "mdi:cog": "gear",
        "mdi:settings": "gear",
        "mdi:power": "power",
        "mdi:check": "checkmark",
        "mdi:close": "xmark",
        "mdi:plus": "plus",
        "mdi:minus": "minus",
        "mdi:search": "magnifyingglass",
        "mdi:refresh": "arrow.clockwise",

        // Browser
        "mdi:safari": "safari.fill",
        "mdi:web": "globe",
        "mdi:link": "link",

        // Media & Audio
        "mdi:music": "music.note",
        "mdi:spotify": "music.note.list",
        "mdi:play": "play.fill",
        "mdi:pause": "pause.fill",
        "mdi:stop": "stop.fill",
        "mdi:skip-next": "forward.fill",
        "mdi:skip-previous": "backward.fill",
        "mdi:volume-high": "speaker.wave.3.fill",
        "mdi:volume-medium": "speaker.wave.2.fill",
        "mdi:volume-low": "speaker.wave.1.fill",
        "mdi:volume-off": "speaker.slash.fill",
        "mdi:speaker": "speaker.wave.2",

        // Camera & Video
        "mdi:camera": "camera.fill",
        "mdi:video": "video.fill",
        "mdi:cctv": "video",
        "mdi:video-doorbell": "video.doorbell.fill",

        // Communication
        "mdi:message": "message.fill",
        "mdi:phone": "phone.fill",
        "mdi:email": "envelope.fill",
        "mdi:bell": "bell.fill",
        "mdi:bell-outline": "bell",

        // Time & Calendar
        "mdi:clock": "clock.fill",
        "mdi:calendar": "calendar",
        "mdi:alarm": "alarm",
        "mdi:timer": "timer",

        // Weather
        "mdi:weather-sunny": "sun.max",
        "mdi:weather-cloudy": "cloud",
        "mdi:weather-rainy": "cloud.rain",
        "mdi:weather-partly-cloudy": "cloud.sun",
        "mdi:weather-snowy": "cloud.snow",
        "mdi:weather-windy": "wind",
        "mdi:thermometer": "thermometer",
        "mdi:water-percent": "humidity",
        "mdi:humidity": "humidity",

        // Home & Security
        "mdi:home": "house.fill",
        "mdi:home-assistant": "house.fill",
        "mdi:shield": "shield.fill",
        "mdi:shield-home": "shield.fill",
        "mdi:lock": "lock.fill",
        "mdi:lock-open": "lock.open.fill",
        "mdi:door": "door.left.hand.open",
        "mdi:door-open": "door.left.hand.open",
        "mdi:door-closed": "door.left.hand.closed",
        "mdi:window-open": "window.vertical.open",
        "mdi:window-closed": "window.vertical.closed",
        "mdi:garage": "rectangle.split.3x1",
        "mdi:motion-sensor": "figure.walk.motion",
        "mdi:run": "figure.run",

        // Lighting
        "mdi:lightbulb": "lightbulb.fill",
        "mdi:lightbulb-on": "lightbulb.fill",
        "mdi:lightbulb-off": "lightbulb.slash",
        "mdi:lamp": "lamp.desk.fill",
        "mdi:ceiling-light": "light.recessed",
        "mdi:floor-lamp": "lamp.floor.fill",

        // HVAC & Climate
        "mdi:thermostat": "thermostat",
        "mdi:fan": "fan",
        "mdi:air-conditioner": "air.conditioner.horizontal",
        "mdi:snowflake": "snowflake",
        "mdi:fire": "flame.fill",

        // Power & Energy
        "mdi:flash": "bolt.fill",
        "mdi:lightning-bolt": "bolt.fill",
        "mdi:battery": "battery.100",
        "mdi:battery-charging": "battery.100.bolt",
        "mdi:solar-power": "sun.max.trianglebadge.exclamationmark",
        "mdi:ev-station": "bolt.car",
        "mdi:power-plug": "powerplug.fill",
        "mdi:gas-station": "fuelpump",

        // Appliances
        "mdi:washing-machine": "washer",
        "mdi:dishwasher": "dishwasher",
        "mdi:fridge": "refrigerator",
        "mdi:stove": "stove",
        "mdi:microwave": "microwave",
        "mdi:coffee": "cup.and.saucer",
        "mdi:vacuum": "humidifier.and.droplets",

        // Devices
        "mdi:television": "tv",
        "mdi:monitor": "display",
        "mdi:laptop": "laptopcomputer",
        "mdi:tablet": "ipad",
        "mdi:cellphone": "iphone",
        "mdi:wifi": "wifi",
        "mdi:bluetooth": "antenna.radiowaves.left.and.right",
        "mdi:printer": "printer",
        "mdi:router": "wifi.router",

        // People & Location
        "mdi:account": "person.fill",
        "mdi:account-multiple": "person.2.fill",
        "mdi:car": "car.fill",
        "mdi:map": "map.fill",
        "mdi:map-marker": "mappin",
        "mdi:navigation": "location.north.fill",

        // Sensors & Gauges
        "mdi:gauge": "gauge",
        "mdi:speedometer": "speedometer",
        "mdi:sensor": "sensor.fill",
        "mdi:water": "drop.fill",

        // Dashboard
        "mdi:view-dashboard": "rectangle.grid.2x2.fill",
        "mdi:view-dashboard-outline": "rectangle.grid.2x2",
    ]

    /// Convert an MDI icon name to an SF Symbol
    /// - Parameter mdiName: The MDI icon name (e.g., "mdi:thermometer")
    /// - Returns: The corresponding SF Symbol name, or "questionmark.circle" if not found
    public static func sfSymbol(from mdiName: String) -> String {
        mdiToSFSymbol[mdiName] ?? "questionmark.circle"
    }

    /// Convert an MDI icon name to an SF Symbol, with a custom default
    /// - Parameters:
    ///   - mdiName: The MDI icon name
    ///   - defaultSymbol: The default SF Symbol to use if no mapping exists
    /// - Returns: The corresponding SF Symbol name
    public static func sfSymbol(from mdiName: String, default defaultSymbol: String) -> String {
        mdiToSFSymbol[mdiName] ?? defaultSymbol
    }
}
